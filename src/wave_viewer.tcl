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
  # signal-browser PLAN item 8: the LEFT SIDEBAR's per-window state. TWO arrays,
  # deliberately the `gridshow` shape: `browser` is the AUTHORITY (0/1 = the
  # sidebar is packed) and `browsershow` exists ONLY because Tk's checkbutton
  # -variable needs a global it can write. Collapsing them into one would make
  # the menu variable the state, and a key press would then have no way to be
  # wrong about it -- which sounds like a feature and is actually the loss of an
  # observable seam (tab_thaw's wording, :9330).
  # PER TOKEN AND DELIBERATELY NOT PER TAB: `layouts` and `cvr` are frozen and
  # thawed by tab_freeze/tab_thaw, and a sidebar listing the WINDOW's raw
  # inventory (one xctx, one raw, shared by every tab) must not blink on a tab
  # switch. Items 9-15 inherit this.
  variable browser;     array set browser {}
  variable browsershow; array set browsershow {}
  # signal-browser PLAN item 9: the sidebar's CONTENT state, per window.
  #   browsersigs($token) = the raw inventory SNAPSHOT (full raw names, settled
  #     decision 2), taken by browser_reload each time the sidebar is shown.
  #     `atdsigs`-shaped and for the same reason: a snapshot means a keystroke
  #     in either bar costs no 0173 context loan. Its declared limit is that a
  #     raw loaded AFTER the sidebar was shown needs a re-show (item 13/15).
  #   browserrows($token) = the row list currently in the treeview, so the plot
  #     gestures can turn a row id back into full raw names without re-deriving
  #     anything from the widget.
  variable browsersigs; array set browsersigs {}
  variable browserrows; array set browserrows {}
  #   browserdbsigs($token) = signal-browser item 14 (All DBs). The FOREIGN
  #     results databases' inventories — one entry per NON-current raw in
  #     `xctx->extra_raw_arr`, {id d:<idx> label <file (analysis)> names {..}} —
  #     taken by the SAME snapshot browsersigs is (item 9's D6, extended). It is
  #     filled UNCONDITIONALLY on reload so that the All-DBs checkbox has exactly
  #     ONE reader, in browser_refresh, and the snapshot cost does not depend on
  #     widget state.
  variable browserdbsigs; array set browserdbsigs {}
  #   browserraw($token) = TWO-PANE item 10. The CURRENT DB's raw path, captured
  #     by browser_reload in the SAME pass browserdbsigs is, so the tree's design
  #     root can be named without browser_refresh taking a context loan per
  #     keystroke. `browser_root_label` turns it into the root row's text and
  #     answers `design` when it is empty, so a missing capture degrades to a
  #     named root rather than to no root at all.
  variable browserraw; array set browserraw {}
  #   browsercurdb($token) = TWO-PANE item 15 (spec R7). `{id d:<idx> label ..}`
  #     for the CURRENT results database, captured by browser_reload in the SAME
  #     pass as browserraw and browserdbsigs, for the same reason: with All-DBs
  #     ticked the current DB needs a header of its own and browser_refresh rides
  #     both searchbars' key pump, so it must not take a context loan per
  #     character to learn its own label. An absent or empty entry degrades to
  #     the flat unlabelled group item 14 shipped — a missing capture costs the
  #     current DB its header, never a throw.
  variable browsercurdb; array set browsercurdb {}
  # TWO-PANE item 11: the LOWER pane's four per-token pieces.
  #   browserseaent($token) = the entry snapshot the SEA is drawn from: the
  #     BAR-MATCHED half of browsersigs, class-filtered. ⚠ IT IS A DIFFERENT SET
  #     FROM THE TREE'S, and deliberately so — spec §7.1 derives the tree from
  #     the BAR-UNFILTERED inventory (item 10) while R5 scopes both bars to the
  #     lower pane. One array per pane is what makes "the bars moved the sea and
  #     left the tree alone" an assertable pair of values rather than a claim.
  #   browsersea($token) = the ordered {label fullname} pairs CURRENTLY DRAWN,
  #     index-parallel to the canvas's `n<idx>` tags. ⚠ THE FULL RAW NAME LIVES
  #     HERE, NEVER IN THE CANVAS TEXT: the label is a display (spec R8 collides
  #     four times in the corpus) and every gesture resolves through the index.
  #   browserseasel($token) = the selection, a SET of indices into browsersea
  #     (spec §5.3). A list, not a single index — Shift and Control extend it.
  #   browserseaanchor($token) = the index Shift-click extends FROM.
  #   browserseadbent($token) = §F item F6 (issue 0308). THE SEA'S PER-DATABASE
  #     DIMENSION: a dict `d:<registry idx>` -> that FOREIGN database's own
  #     bar-matched, class-filtered entry list, written by browser_refresh's
  #     All-DBs loop in the SAME pass as the tree group it describes, so the two
  #     cannot disagree about which rows exist. ⚠⚠ IT IS SEPARATE FROM
  #     `browserseaent` RATHER THAN AN EXTRA KEY IN IT because `browserseaent`
  #     IS the current database's list and a dozen readers (BW/BX/BQ/BP bands,
  #     the two-pane counters) take its `llength` as "how many signals the pane
  #     can draw". Widening that value would move every one of them for a fact
  #     none of them is about. ⚠ A FOREIGN SLOT WITH NO ENTRY HERE ANSWERS
  #     NOTHING, NEVER THE CURRENT DATABASE'S ENTRIES — issue 0308's whole point
  #     is that a wrong answer beats no answer only in the other direction.
  variable browserseadbent;  array set browserseadbent  {}
  #   browserseadbid($token) = the TREE ROW ID the pane's cells were drawn for,
  #     or {} when the pane is not drawn from a row at all. ⚠ IT IS THE ROW ID
  #     AND NOT THE REGISTRY INDEX: `browser_row_db` projects the index out of
  #     it and `browser_id_type` projects the database KIND, so one written fact
  #     answers both of the pane's two per-database questions (which raw does a
  #     Plot land against, and whose grammar does a Descend-to split with) and
  #     they cannot drift apart. Written by browser_sea_refresh and nowhere else.
  variable browserseadbid;   array set browserseadbid   {}
  variable browserseaent;    array set browserseaent    {}
  variable browsersea;       array set browsersea       {}
  variable browserseasel;    array set browserseasel    {}
  variable browserseaanchor; array set browserseaanchor {}
  #   browserseanote($token) = §F's F5 NOTICE: one sentence explaining why the
  #     lower pane has nothing to show, or {}. It is set by a GESTURE that
  #     refused (Ctrl-Alt-V on a code block whose digital data is missing) and
  #     CLEARED at the top of every sea refresh, so it lives exactly as long as
  #     the pane it explains: the next node the user selects redraws that pane
  #     and the sentence goes with it. Nothing persists it — a stale reason on a
  #     pane that has since been repopulated would be worse than no reason.
  #     ⚠⚠ "EVERY REFRESH" MEANS EVERY NAVIGATION, AND ISSUE 0318 IS WHAT THE
  #     DIFFERENCE COSTS. A `<Configure>` on the sea canvas — issue 0312's width
  #     grip, the sash, the toplevel resized, a window manager tiling it — comes
  #     through the same refresh, and clearing there wiped the sentence off a
  #     pane the user had only made NARROWER: it went back to being the
  #     unexplained empty box F5 exists to abolish. The geometry door therefore
  #     asks the refresh to KEEP the notice; the DEFAULT is still to clear, so a
  #     caller that declares nothing is a navigation and cannot leave a stale
  #     reason behind.
  variable browserseanote;   array set browserseanote   {}
  # THE HOVER TOOLTIP (item 11's eighth gesture, paid beside item 20). The pane
  # draws a LABEL; this is how the user sees the NAME behind it.
  #   seatipdelay = ms of hover before a tip appears. A VARIABLE, not a literal,
  #     for the reason `balloon` takes the same argument: a tip that appears on
  #     the first pixel of movement is noise. A test sets it to 0 and restores.
  #   seatippoll = ms between the watchdog's containment checks. It is also the
  #     worst-case staleness after the pointer leaves the pane, which is what
  #     buys the tooltip its ONE bind (see browser_sea_tip_watch).
  #   seatipafter($token) = the pending `after` id -- a SHOW while none is
  #     posted, the WATCHDOG re-arm while one is. One id, cancelled one way.
  #   seatipidx($token) = the row the posted tip is about, and the thing that
  #     makes "the pointer has not left this cell" answerable without work.
  variable seatipdelay 600
  variable seatippoll  200
  variable seatipafter;      array set seatipafter      {}
  variable seatipidx;        array set seatipidx        {}
  # TWO-PANE item 9: the paned skeleton's three per-token pieces.
  #   browsersash($token) = the split between the instance tree and the sea of
  #     names, as a FRACTION of the panedwindow's height (M3), never pixels. A
  #     fraction because the sidebar's height is the toplevel's and the toplevel
  #     is resized freely; and because `browser_state` validates `width` with
  #     `string is integer -strict`, so the sash could not have ridden inside it
  #     (spec §9). Applied only on a MAPPED pane -- `sashpos` on an unmapped one
  #     computes fraction x 0 and collapses the tree pane (MEASURED: unmapped
  #     `winfo height` 1, `sashpos 0` 0).
  #   browserdev($token) / browsersrc($token) = R11's two independent class
  #     filters, `Show device internals` (default 0) and `Show source currents`
  #     (default 1). ⚠ PER TOKEN, not namespace globals: two viewers showing two
  #     raws must be able to disagree. INERT in item 9 -- the checkbuttons are
  #     built and packed with NO `-command`; item 12 wires them.
  # ⚠ ALL THREE ARE NOW PERSISTED (TWO-PANE item 14, spec §9) -- they ride in
  # the `browser` sub-dict of the session state. The arrays stay PER TOKEN and
  # are still unset in the teardown block; a restore writes them through the
  # accessors, never around them. ⚠ `browsersash($token)` in particular is only
  # ever written by a real sash drag or by a restore, and its ABSENCE is the
  # meaningful state "nobody chose a split" -- do not re-seed it at build time.
  variable browsersash; array set browsersash {}
  variable browserdev;  array set browserdev  {}
  variable browsersrc;  array set browsersrc  {}
  # issue 0312: THE SIDEBAR WIDTH PREFERENCE, and the live drag's two anchors.
  # Same shape and the same rule as `browsersash` one line up: `browserwidth`'s
  # ABSENCE means "nobody dragged the divider and no state restored one", so it
  # is never seeded at build time -- but unlike the sash it IS seeded by the
  # FIRST show, because `browser_width`'s derived base is read off the search
  # bar's `reqwidth` and that number changes when the bar wraps (see
  # `searchbar_reflow`). Without the seed, a hide/show after a wrap would
  # re-derive from the WRAPPED bar and collapse the sidebar onto its 240 px
  # floor. `gripdrag($token)` is the {rootx width} pair captured on <Button-1>,
  # and it is a LIST rather than two arrays so the teardown sweep has one entry
  # to drop.
  variable browserwidth; array set browserwidth {}
  variable gripdrag;     array set gripdrag     {}
  # issue 0315, RULING (1) — "the ASE command owns the CIW account". A ONE-SHOT
  # per-token flag, armed by the caller immediately before a
  # `browser_show_path`/`browser_show_db_scope` call and CONSUMED by the
  # `browser_say` that call ends in. It suppresses the CIW echo only; the
  # sidebar status line is written on every branch either way, because that
  # line is decision 4's surface and nobody ruled it away.
  #
  # ⚠ A FLAG AND NOT AN ARGUMENT, AND THAT IS FORCED. Two suites STUB the two
  # entry points with their shipped arity —
  # `proc ::wviewer::browser_show_path {token path}` in
  # `test_ase_cosim.tcl` and `test_wave_sigbrowser_i12.tcl` — so a third
  # positional argument passed by `ase.tcl` would make the real caller invoke a
  # stub with too many arguments and red both files for a reason that has
  # nothing to do with what they test.
  #
  # ⚠ ONE-SHOT, AND SAFE ONLY BECAUSE EVERY RETURN PATH THROUGH BOTH ENTRY
  # POINTS IS `return [wviewer::browser_say ...]` — MEASURED at 8 of 8 in
  # `browser_show_path` and 11 of 11 in `browser_show_db_scope`, no bare
  # `return` in either. So an armed flag is always consumed exactly once, and
  # BE15 in `tests/headless/test_wave_sigbrowser_0315.tcl` pins both counts
  # because a future early return is what would break it silently.
  #
  # ⚠ THE TAIL DISARM IN `ase.tcl` IS NOT A GUARANTEE ON THE THROW PATH. The
  # three viewer calls there are unguarded, so an error raised inside one skips
  # the disarm and leaves the flag armed for the next gesture, which would then
  # report one line fewer. Nothing today can raise there (both entry points are
  # built not to throw, for the bgerror reason this file repeats), which is why
  # the disarm is a sweep and not a `finally` — but the limit is real and is
  # recorded rather than papered over.
  variable sayquiet;     array set sayquiet     {}
  # signal-browser PLAN item 13: the Location bar's RAW HISTORY. A single
  # GLOBAL list (newest first, deduped on the normalised path, capped at
  # $::raw_history_max), NOT a per-token array: "the last raws I opened" is a
  # property of the USER, exactly like $tctx::recentfile, and every viewer
  # window offers the same dropdown. Persisted to $USER_CONF_DIR/raw_history
  # as a Tcl-sourceable line -- the recent_files shape, because the PLAN's
  # "the same way other viewer prefs are" turned out to be a FALSE PREMISE:
  # `grep USER_CONF_DIR wave_viewer.tcl` had zero hits before this item, i.e.
  # NO viewer pref was persisted anywhere. Never written from a gated
  # (--nogui/--pipe/--script) session -- issue 0119, see rawhist_push.
  variable rawhist {}
  # issue 0151: per-window PLOT MODE (single|multi) and TARGET STRIP (model
  # graph index). Window properties, not graph properties — hence arrays
  # keyed by session token like the mirrors above, NOT layout-dict keys (the
  # layout dict is rebuilt wholesale by restore/set_graphs). `target` is
  # stored raw and clamped on every read (wviewer::target_index), so
  # deleting a strip can never leave a dangling target.
  variable mode;    array set mode {}
  variable target;  array set target {}
  # signal browser batch item 7: per-window PLOT DESTINATION
  # (append|replace|newstrip|newtab) — ViVA's Append/Replace/NewSubWin/NewWin
  # mapped onto xschem's model. Keyed by session token like `mode`/`target`
  # above, and for the same reason: it is a WINDOW property, not a layout key.
  #
  # ⚠ DELIBERATELY NOT a per-TAB field, unlike `mode` and `target`, which
  # tab_freeze/tab_thaw carry in the tab record. The settled wording is
  # "persisted per WINDOW": ONE destination governs every tab of the window, so
  # switching tabs cannot silently change where the next plot lands. The
  # asymmetry with mode/target is intentional — do not "fix" it by adding a
  # `dest` key to the tab record without changing that decision first.
  variable dest;    array set dest {}
  # per-dialog transient state (D13), cleaned on OK/cancel/forget
  variable axl;     array set axl {}
  variable delmap;  array set delmap {}
  # per-SEARCHBAR state (signal browser batch item 4), keyed by the megawidget's
  # own frame path — NOT by session token, because a searchbar is not a per-window
  # singleton: item 5 puts one in the Add Trace dialog and item 8 another in the
  # browser sidebar of the SAME viewer window. Dropped by the bar's own <Destroy>
  # handler (wviewer::searchbar_destroyed), so a destroyed bar leaves nothing.
  #   sbcfg($w)  = {command <cb prefix> showbutton <0|1>}
  #   sbcase($w) = the Match-case checkbutton's -variable (0 = ViVA's default)
  #   sballdb($w) = the All-DBs checkbutton's -variable, on the bars built with
  #     `-alldbs 1` only (signal-browser item 14). Same lifecycle as sbcase.
  #   sbwrap($w) = 1 while the bar is laid out on TWO ROWS (issue 0312). Same
  #     lifecycle again; its absence means the flat one-row layout, which is the
  #     shape `searchbar_build` always leaves behind.
  variable sbcfg;   array set sbcfg  {}
  variable sbcase;  array set sbcase {}
  variable sballdb; array set sballdb {}
  variable sbwrap;  array set sbwrap  {}
  # Add Trace dialog's signal inventory (item 5), keyed by SESSION TOKEN — the
  # dialog IS a per-window singleton (`$top.wvadd`), unlike the searchbar above.
  # The FULL raw names (settled decision 2), snapshotted once when the dialog
  # opens so the live filter never re-enters the context on every keystroke.
  # Dropped by the dialog's own <Destroy> (wviewer::add_trace_forget).
  variable atdsigs; array set atdsigs {}
  #   atddb($token) = §F item F6 (issue 0308). THE ONE-SHOT DATABASE the
  #     browser's LOWER PANE sends with a name it prefilled into the dialog:
  #     `{<the exact prefilled name> <registry index>}`. `plot_dbs_arm`'s shape,
  #     one dialog over, and for the identical reason — a foreign pane's name can
  #     collide with a current-database name, and `add_trace`'s name search
  #     resolves a collision to THE CURRENT DATABASE. ⚠ THE NAME IS HALF THE ARM:
  #     the dialog is modeless and its Expression field is meant to be EDITED, so
  #     the index is honoured only while the text is still byte-for-byte the one
  #     it was armed with. CONSUMED by OK and dropped by the dialog's own
  #     <Destroy> (`add_trace_forget`, the single owner) — which `dialog_frame`'s
  #     unconditional `catch {destroy $w}` also makes the reason a REOPENED form
  #     is never born armed. `forget` sweeps it with the window.
  variable atddb;   array set atddb   {}
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
  # ---- TABS (doc/claude/specs/waveform_viewer_tabs.md) ----------------------
  # THE STASH (D2). Every per-view-content array above keeps its session-token
  # key and always describes the ACTIVE tab; the INACTIVE tabs live frozen
  # here, so not one existing proc changes its key and a Direct Plot lands in
  # the active tab for free. One record per tab, in bar order:
  #   {id N name S layout L mode M target T cva a cvb b cvr r
  #    undo U redo R wavehl W view V}
  variable tabstash; array set tabstash {}
  # token -> the ACTIVE tab's INDEX into that list
  variable curtab;   array set curtab {}
  # token -> next tab id to mint. Monotonic and NEVER reused: the id is inert
  # (nothing behavioural reads it) and exists so a test can witness "it landed
  # in the tab that was second" independently of "the tabs got reordered".
  variable tabseq;   array set tabseq {}
  # The trace CLIPBOARD (D12). One per session, not per window, so a copy can
  # cross windows as well as tabs. Shape:
  #   {from {<token> <tabid>} raw {<rawfile> <sim_type>}
  #    items {{gi <source model strip> tr {expr .. name .. vec .. color ..}} ...}}
  # The per-item SOURCE STRIP INDEX is the whole of what "keep their
  # separateness" needs -- the groups are derived from it, so nothing else
  # about the source layout has to be copied. Deliberately NOT graph dicts:
  # those carry `auto`, `markers`, `hilight_wave`/`sel_waves` and axis ranges,
  # all meaningless or harmful in another strip.
  variable clip {}
}

# --- the message seam (R6 / issue 0207) --------------------------------------
#
# ⚠ `ciw_echo` ALONE DOES NOT SATISFY "logged to the CIW and the log file".
# Issue 0207 measured exactly that: a pane message reaches the CIW's mirror and
# never the log FILE. This is the ase::echo shape (src/ase.tcl) -- both halves,
# both catch'd, and NO `::has_x` guard on the pane half, because that guard is
# precisely what 0207 identified as the suppressor.
#
# Scope, deliberately: only the TAB messages route through here. Converting the
# ~120 pane-only ciw_echo sites in this file is 0207's own deferred item 2 and
# would collide with everything else in flight.
# ⚠ 0650: THIS PROC AND ase::echo WERE THE SAME EIGHT LINES OF CODE -- the
# channel had TWO builders before this step, which is invariant I1's exact
# prohibition, and a drift between them would have failed SILENTLY. The body now
# lives once, in `xschem::notify` (src/ciw.tcl). Name, signature and every call
# site here are unchanged; ::xschem::notify is resolved at CALL time because
# ciw.tcl is sourced after this file (src/xschem.tcl:14854 vs :14806).
## ⚠ 0658: the catch that used to live here HID the defect. `::xschem::notify`
## lives in src/ciw.tcl, which src/xschem.tcl sources AFTER this file, so one
## unavailable proc in another file turned every call site into a silent no-op
## -- the durable log line included, and that line had been INLINE here before
## 0650. The body is now `::xschem::notify_safe` (src/xschem.tcl, defined before
## every caller): it still never propagates -- a notice may not break a pick or
## a netlist -- but a raise now falls back to the degraded bootstrap channel
## instead of returning a silent, untrue 0. ONE delegate body, shared with
## wviewer::echo, which is what invariant I1 asks for.
##
## ⚠ ISSUE 0666: THE GUARANTEE IS BACK IN THIS BODY. 0658's brief said "a notice
## must never break its caller"; the catch was not deleted, it MOVED into the
## callee, and this line became a bare one-liner that raises `invalid command
## name "::xschem::notify_safe"` straight into a pick or a netlist the moment
## the delegate body is not there.
##
## REACHABILITY, MEASURED, AND NARROWER THAN 0666 CLAIMED: the FILE-LOAD path is
## CLOSED by issue 0663 (src/xinit.c:3571 -- a partially loaded xschem.tcl now
## exits 1 with an announced STARTUP ABORTED), and notify_safe is defined before
## this file is sourced, so no ordering can leave the delegate without it. What
## IS live is a RUNTIME `namespace delete ::xschem`: it succeeds, takes the
## namespace from 13 procs to 0, leaves the C `xschem` command working, and is
## reachable from ciw_exec's `uplevel #0 $cmd` (src/ciw.tcl:557) and from any
## --script. Hence a two-line guard here, and NOT a loader-level one.
##
## The guard is INLINE in each delegate on purpose, four lines duplicated
## deliberately: extracting it into a shared proc would put it in the very
## namespace whose absence it exists to survive (0666: "a guard is not a
## builder"). What it returns is TRUE (0652): nothing reached any sink, and
## stderr is never counted as one (0658 D9), so 0 is the honest answer -- never
## a 0 that merely means "I did not check".
proc wviewer::echo {msg {tag {}}} {
  if {[catch {::xschem::notify_safe $msg $tag} r]} {
    catch {puts stderr "xschem: notice channel unavailable: $r" ; flush stderr}
    return 0
  }
  return $r
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
  wviewer::diag "forget         token=$token"
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
  # item 7: DECLARED here on purpose — see the `gridshow` note just above for
  # what an undeclared `variable` costs (a silent per-token leak that survives
  # every close).
  variable dest
  # signal-browser item 8: DECLARED here for the same reason `dest` and
  # `gridshow` are -- an undeclared `variable` makes the unsets below address a
  # LOCAL array, so the namespace entries survive every close.
  variable browser; variable browsershow
  # signal-browser item 9: the inventory SNAPSHOT and the last row list, same
  # rule -- an undeclared `variable` leaks one entry per closed window forever.
  variable browsersigs; variable browserrows
  # signal-browser item 14: the foreign-DB inventory snapshot, same rule again.
  variable browserdbsigs
  # TWO-PANE item 10: the current DB's raw path, same rule.
  variable browserraw
  # TWO-PANE item 15: the current DB's header identity, same rule.
  variable browsercurdb
  # TWO-PANE item 11: the lower pane's snapshot, its drawn pairs, its selection
  # and its Shift anchor — same rule a fourth time.
  variable browserseaent; variable browsersea
  variable browserseasel; variable browserseaanchor
  # §F item F6 (issue 0308): the sea's per-database dimension and the row it is
  # currently drawn for, same rule again — a foreign inventory left behind on a
  # closed window would be a second, staler answer to "whose names are these".
  variable browserseadbent; variable browserseadbid
  # §F item F5: the empty-pane notice, same rule again.
  variable browserseanote
  # TWO-PANE item 9: the sash fraction and R11's two class filters, same rule
  # a third time.
  variable browsersash; variable browserdev; variable browsersrc
  # issue 0312: the sidebar width preference and the grip's drag anchors, same
  # rule again. The grip WIDGET is a child of $top and dies with the toplevel;
  # these two arrays are keyed by token and would not.
  variable browserwidth; variable gripdrag
  # issue 0315: the one-shot CIW-echo suppression flag, same rule again — and
  # with `plotdbs`' caveat just below, verbatim: it is normally consumed by the
  # `browser_say` of the call it was armed for, so this is the SWEEP, not the
  # owner. A window closed between an arm and its say would otherwise leave the
  # entry forever.
  variable sayquiet
  # spec §D1 (DEFECT 2): the armed per-signal database list, same rule again.
  # It is one-shot and normally already consumed, but a window closed between an
  # arm and its plot_signals would otherwise leave the entry forever.
  variable plotdbs
  # §F item F6: the Add Trace dialog's twin of that arm, same rule again — and
  # with plotdbs' own caveat, verbatim: the dialog's <Destroy> is its single
  # owner and normally drops it first, so this is the SWEEP, not the owner. It
  # cannot be reddened by deleting it while a dialog destroy always precedes a
  # window destroy; it is written because the file's rule is that every
  # per-token array is dropped here.
  variable atddb
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
    # item 10: the browser's row menu is a THIRD tk_popup grab that must not
    # outlive its widget. Item 11's SEA menu is a FOURTH — a DISTINCT widget
    # (`wvseamenu`), so it needs its own unpost; the tree's would not reach it.
    catch {wviewer::browser_menu_unpost $token}
    catch {wviewer::browser_sea_menu_unpost $token}
    # the hover tooltip is an override-redirect toplevel and a pending `after`;
    # both must die with the window. Unlike the menus it is not a grab, so it
    # would not freeze the UI — it would just float there over whatever the user
    # opened next, which is worse to diagnose and no harder to prevent.
    catch {wviewer::browser_sea_tip_hide $token}
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
  # tabs: the stash, the active index and the id counter die with the window
  # (doc/claude/specs/waveform_viewer_tabs.md D3). The bar itself is a child of
  # $top and goes with it.
  wviewer::tabs_forget $token
  dict unset layouts $token
  catch {unset cva($token)}
  catch {unset cvb($token)}
  catch {unset cvr($token)}
  catch {unset sharedx($token)}
  catch {unset gridshow($token)}
  catch {unset mode($token)}
  catch {unset target($token)}
  catch {unset dest($token)}
  catch {unset browser($token)}
  catch {unset browsershow($token)}
  catch {unset browsersigs($token)}
  catch {unset browserrows($token)}
  catch {unset browserdbsigs($token)}
  catch {unset browserraw($token)}
  catch {unset browsercurdb($token)}
  catch {unset browserseaent($token)}
  catch {unset browserseadbent($token)}
  catch {unset browserseadbid($token)}
  catch {unset browsersea($token)}
  catch {unset browserseasel($token)}
  catch {unset browserseaanchor($token)}
  catch {unset browserseanote($token)}
  catch {unset browsersash($token)}
  catch {unset browserdev($token)}
  catch {unset browsersrc($token)}
  catch {unset browserwidth($token)}
  catch {unset gripdrag($token)}
  catch {unset sayquiet($token)}
  catch {unset plotdbs($token)}
  catch {unset atddb($token)}
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

# wviewer::ctx_verdict  wp  tops0  tops1  ninst  nwires
#   Decides, from window paths alone, whether the context that
#   `xschem load_new_window -window {}` was supposed to move actually moved, and
#   onto WHICH toplevel the viewer may be built. Extracted from wviewer::open so
#   it is drivable HEADLESS (wviewer::open returns 0 without ::has_x, and
#   everything past the brands is Tk) -- issue 0187.
#     wp     : current_win_path AFTER the create, already repaired by open's
#              recovery loop (which only ever assigns a VERIFIED value)
#     tops0  : `winfo children .` BEFORE the create
#     tops1  : `winfo children .` AFTER  the create
#     ninst  : `xschem get instances` in the landed context
#     nwires : `xschem get wires`     in the landed context
#   Returns {ok <toplevel>} or {err <message>}. The message carries NO "wviewer: "
#   prefix -- wviewer::open owns the prefix, so there is one site for it.
#
# WHY NOT `if {[xschem get current_win_path] ne $wp}`: that WAS the guard until
# 0187, and it compares a value with a re-read of the source it came from, with no
# update and no event loop in between -- it can NEVER fire. Measured trigger: with
# all MAX_NEW_WINDOWS (20, xschem.h:158) slots used, create_new_window() returns
# before creating anything and before (*window_count)++ (xinit.c:1990-1991), rc 0
# and no Tcl error -- so no toplevel exists, the recovery loop finds nothing, the
# context never moved, and wviewer::open branded the user's live schematic
# readonly/no_grid/no_snap/graph_snap_cursor/wave_viewer and registered it as the
# viewer. The intended target is not a path anybody hands us; it is "a toplevel
# THIS call created", so that is what we test.
#
# Sound in BOTH window models: `-window` sets force_window=1 and an empty file arg
# takes new_schematic("create_window",...) (scheduler.c), which in xinit.c ALWAYS
# calls create_new_window regardless of tabbed_interface, and create_new_window
# does `toplevel .xN` -- a direct child of `.` either way. So "appeared in
# `winfo children .`" is not a non-tabbed-only test.
proc wviewer::ctx_verdict {wp tops0 tops1 ninst nwires} {
  regsub {\.drw$} $wp {} top
  if {$top eq {}} { set top . }
  # (1) pre-existing rule, unchanged: a viewer on the ROOT window cannot work --
  #     its widgets are `$top.<name>`, which for `.` concatenates to `..<name>`.
  if {$top eq {.}} {
    return [list err "could not give the waveform viewer its own window"]
  }
  # (2) THE 0187 REPAIR: the context must have landed on a toplevel that did not
  #     exist before this call.
  if {[lsearch -exact $tops1 $top] < 0 || [lsearch -exact $tops0 $top] >= 0} {
    return [list err "the waveform window did not take the context, refusing"]
  }
  # (3) THE BELT (0187 "Direction", third option): a viewer buffer never holds a
  #     schematic. Pure belt -- a create_window buffer is measured 0/0 -- so it
  #     cannot false-refuse, but it stops a brand dead if (2) is ever weakened.
  if {$ninst != 0 || $nwires != 0} {
    return [list err "refusing to brand a window that holds a schematic"]
  }
  return [list ok $top]
}

# Raise-or-open the ONE viewer window of ASE session `token`. Returns 1 when
# the viewer is up (raised or freshly built), 0 on an unknown token (ciw_echo
# under has_x, never a throw — ase::open_state style) and 0 headless (the
# window shell is GUI-only; the session bookkeeping stays untouched).
# --- window geometry: the viewer is NOT an untitled scratch buffer ------------
#
# ⚠ issue 0840, MEASURED. store_geom/set_geom (src/xschem.tcl) key a window's
# saved geometry by `[xschem get current_name]`, and the viewer is built on a
# schematic buffer whose name is `untitled.sch`. So the viewer and EVERY
# untitled scratch buffer in the program shared ONE slot in
# $USER_CONF_DIR/geometry:
#
#     sky130A/.../tb_bandgap.sch   1110x761+404+132   <- the design window
#     untitled.sch                 1110x761+404+132   <- the viewer, restored
#                                                        pixel-for-pixel on top
#
# The user reported it as "the schematic window appears to get replaced by a
# Waveform Window": two mapped toplevels at exactly the same geometry, so the
# design window is 100% occluded and the taskbar preview shows the waveform for
# both. Reproduced on Xvfb + openbox with identical numbers, so it is not a
# window-manager quirk and not the VcXsrv compositing of issue 0680.
#
# ⚠ AND THE NUMBERS IN THAT SLOT ARE THE MAIN WINDOW'S OWN, which is why the
# overlap is EXACT rather than merely likely, and why it happens every session:
#
#   1. xschem starts with `untitled.sch` in the main window;
#   2. the user loads a schematic, and the load path stores the geometry FIRST
#      -- `store_geom [xschem get topwindow] [xschem get current_name]`
#      (scheduler.c:7656) with current_name still `untitled.sch`, so the MAIN
#      WINDOW's geometry lands in the untitled slot;
#   3. wviewer::open's buffer is `untitled.sch` too, so set_geom hands it back.
#
# The read half below is therefore the load-bearing one. The write half matters
# in the NON-tabbed window model, where store_geom persists arbitrary windows
# (under the tabbed interface it is main-window-only) and the viewer would
# otherwise overwrite that slot with its own place -- moving the next File > New.
#
# The viewer already marks its context as not-a-scratch-buffer (`xschem set
# wave_viewer 1`, issue 0172, for exactly this family of confusion). Geometry
# never got the memo. This gives it its own key.
#
# Keyed by the TOPLEVEL PATH, not the context: store_geom runs from C at moments
# when the current context may be somebody else's, so a per-context flag cannot
# answer "whose window is this".
# --- OPT-IN DIAGNOSTIC TRACE (issue 0840 residuals 1-3) ----------------------
#
# TEMPORARY, and tied to 0840: remove it when the residuals close.
#
# Three things the user sees on their bench that do NOT reproduce on the dev
# display: a SECOND viewer window hiding behind the first, that window's WM
# title reading `untitled.sch (read-only)` instead of `Waveforms ...`, and
# ase::ui::viewer_restore opening nothing at all here despite the state file
# carrying `viewer {open 1 ...}`. All three are questions about WHEN, HOW OFTEN
# and THROUGH WHICH ARM open() is entered -- which is exactly what a report from
# the bench cannot answer and a trace can.
#
# Off unless $env(WVDIAG) is set, and the whole body is catch-wrapped: a
# diagnostic that can break the thing it is diagnosing is worse than none.
proc wviewer::diag {tag {extra {}}} {
  if {![info exists ::env(WVDIAG)] || $::env(WVDIAG) eq {}} { return }
  # ⚠ IT WRITES INTO THE ACTION LOG, NOT A FILE OF ITS OWN. The first version
  # opened /tmp/wvdiag.log and, under the user's own rc, the `open` itself
  # failed -- so the trace was silently empty and looked exactly like "the event
  # never happened", which is the one thing a diagnostic must never look like.
  # `xschem log_action` is already the mechanism the user's `--logdir /tmp` run
  # uses, so the trace lands in the file they ALREADY send, with no second
  # channel to go wrong. The `#= ` prefix is the shipped convention for a
  # non-replayable comment (util.c:538), so the log stays source-able.
  set toks {} ; catch {set toks [dict keys $::wviewer::windows]}
  set cwp {}  ; catch {set cwp [xschem get current_win_path]}
  catch {xschem log_action "#= wvdiag $tag ctx=$cwp registry={$toks} $extra"}
  # every MAPPED toplevel with its title and geometry -- residual 1 is a COUNT
  # and residual 2 is a TITLE, so both are read straight off this list
  set kids {} ; catch {set kids [winfo children .]}
  foreach t [concat . $kids] {
    set cls {} ; if {[catch {winfo class $t} cls]} continue
    if {$t ne {.} && $cls ne {Toplevel}} continue
    set st ? ; catch {set st [wm state $t]}
    if {$st eq {withdrawn}} continue
    set ttl ? ; catch {set ttl [wm title $t]}
    set g ?   ; catch {set g [wm geometry $t]}
    catch {xschem log_action "#=        $t $st $g '$ttl'"}
  }
  return
}

proc wviewer::geom_key {win} {
  variable windows
  if {$win eq {} || ![info exists windows]} { return {} }
  foreach tok [dict keys $windows] {
    if {[catch {dict get $windows $tok top} t]} continue
    if {$t ne {} && $t eq $win} { return {__waveviewer__} }
  }
  return {}
}

# Deterministic backstop for the FIRST open, when no viewer geometry is stored
# yet and placement falls to the window manager. Openbox cascades; nothing
# guarantees the user's does. If the new viewer landed exactly congruent with
# the window it was launched from, step it off. Congruence is the whole defect
# -- a viewer merely NEAR the design window is fine, one exactly on top of it
# reads as the schematic having vanished.
proc wviewer::uncover {top from {tries 4}} {
  if {$top eq {} || $from eq {}} { return 0 }
  if {![winfo exists $top] || ![winfo exists $from]} { return 0 }
  # ⚠ NOT AT CREATION TIME -- AND THAT IS WHY THIS SHOVE NEVER FIRED IN THE FIELD.
  # `wm geometry` reports the REQUESTED geometry until the window has been mapped and
  # the window manager has answered. Called straight out of wviewer::open, it compared
  # a not-yet-placed viewer against the design window, found them different, and did
  # nothing -- and the WM then went on to place the viewer exactly on top anyway.
  # Measured in the user's own session log (window_report, 2026-08-26): viewer `.x1`
  # and design `.` BOTH at 1110x761+3597+340, byte-identical, shove never fired.
  # So wait for the map, then decide. Bounded retries; a viewer the user has already
  # dragged simply will not be congruent by the time we look, which is the right answer.
  if {![winfo ismapped $top] || ![winfo ismapped $from]} {
    if {$tries > 0} { after 120 [list wviewer::uncover $top $from [expr {$tries - 1}]] }
    return 0
  }
  set gt {}; set gf {}
  catch {set gt [wm geometry $top]}
  catch {set gf [wm geometry $from]}
  if {$gt eq {} || $gf eq {}} { return 0 }
  if {[scan $gt {%dx%d+%d+%d} w h x y] != 4} { return 0 }
  if {[scan $gf {%dx%d+%d+%d} fw fh fx fy] != 4} { return 0 }
  # ⚠ TOLERANCE, NOT STRING EQUALITY. Issue 0647's own measurement was
  # 1000x800+13+89 against 1000x800+13+90 -- ONE PIXEL apart, which `eq` calls "not
  # congruent" and a human calls "my schematic is gone". Congruent means the same size
  # and the same corner to within a few pixels. Anything further out is proximity, and
  # U2 says proximity is not the defect.
  set tol 8
  if {abs($w - $fw) > $tol || abs($h - $fh) > $tol} { return 0 }
  if {abs($x - $fx) > $tol || abs($y - $fy) > $tol} { return 0 }
  set dx 48
  set dy 48
  # keep the title bar reachable: step back toward the origin rather than off
  # the bottom-right of the screen
  if {$x + $dx + $w > [winfo screenwidth $top]}  { set dx [expr {-$dx}] }
  if {$y + $dy + $h > [winfo screenheight $top]} { set dy [expr {-$dy}] }
  set nx [expr {$x + $dx}]
  set ny [expr {$y + $dy}]
  if {$nx < 0} { set nx 0 }
  if {$ny < 0} { set ny 0 }
  catch {wm geometry $top ${w}x${h}+${nx}+${ny}}
  return 1
}

proc wviewer::open {token} {
  wviewer::diag "open-ENTER      token=$token"
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
      wviewer::diag "open-REUSE      token=$token top=$top"
      return 1
    }
    wviewer::diag "open-STALEENTRY token=$token top=$top registry had it, window gone"
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
  set tops1 [winfo children .]
  # ⚠ EVERYTHING BELOW STAMPS PER-CONTEXT C STATE, SO VERIFY THE CONTEXT FIRST
  # (issue 0187). The verdict is a pure proc so the rules are testable headless;
  # its three rules and the reasoning behind each live on ctx_verdict itself.
  # `wviewer::open` owns the "wviewer: " prefix so there is exactly one site for
  # it, and the caller already treats 0 as "no viewer" and says so in the CIW.
  set v [wviewer::ctx_verdict $wp $tops0 $tops1 \
           [xschem get instances] [xschem get wires]]
  if {[lindex $v 0] ne {ok}} {
    if {[info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: [lindex $v 1]" error
    }
    return 0
  }
  # the toplevel comes from win_path (.xN.drw -> .xN) rather than
  # `xschem get top_path`, which reports {} under the tabbed interface
  set top [lindex $v 1]
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
  # issue 0840: never land exactly on the window we were launched from. Done
  # AFTER the registry entry so geom_key can already recognise $top.
  set _fromtop [expr {$before eq {.drw} ? {.} : [string range $before 0 end-4]}]
  catch {wviewer::uncover $top $_fromtop}
  wviewer::diag "open-FRESH      token=$token top=$top from=$_fromtop"
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
  # signal-browser item 8: the LEFT sidebar, built HIDDEN (browser_build seeds
  # `browser($token) 0` and the mirror with it). Unpacked, so a viewer that
  # never opens it has the canvas geometry it always had -- the tabbar_build
  # rule, for the same reason.
  wviewer::browser_build $token $top
  # item 18: refit the graph(s) to the new viewport on any canvas resize so the
  # graph ALWAYS fills the window. APPEND (never replace) — <Configure> is in
  # keepseqs and the editor's own resize handler (resetwin+draw) MUST keep
  # running; on_configure debounces to `after idle` and re-fills only on a real
  # size change (D6).
  bind $wp <Configure> "+[list wviewer::on_configure $token]"
  # TABS (doc/claude/specs/waveform_viewer_tabs.md): seed the bookkeeping from
  # the live arrays this proc has just written -- the window opens with exactly
  # ONE tab holding them -- then build the bar UNPACKED. A one-tab viewer never
  # packs it, so its widget tree and its canvas geometry stay byte-identical to
  # the pre-tabs viewer (D7, the issue-0151 "only when there is a choice" rule).
  wviewer::tabs_init $token
  wviewer::tabbar_build $token $top
  wviewer::tabbar_refresh $token
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
  wviewer::diag "open-RETURN     token=$token top=$top"
  # ⚠ AN UNCONDITIONAL CENSUS, twice, at the one moment that matters.
  #
  # The viewer-vs-design confusion is a race, and four sittings have now produced four
  # different arrangements. The WVDIAG-gated trace above answers all of it -- and was
  # switched off on every run that reproduced anything, because a diagnostic you must
  # arm in advance is one you have not armed when the race finally goes your way. The
  # user then has to remember to type `window_report` at exactly the right instant
  # while the thing they are chasing is on screen. That is not a reasonable ask.
  #
  # So the viewer records its own arrival. Two lines of log, at the two instants that
  # separate the competing explanations:
  #   `viewer-open`  -- immediately: how many toplevels exist, and where. One window
  #                     means the design canvas is painting viewer content (a repaint
  #                     defect); two means the viewer is covering it (a placement one).
  #   `viewer-open+` -- after the deferred uncover shove has had its chance to run, so
  #                     the log says whether the anti-congruence step actually fired.
  #                     Issue 0840's shove was dead for days precisely because nothing
  #                     recorded whether it had happened.
  catch {window_report viewer-open}
  catch {after 700 {catch {window_report viewer-open+}}}
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
# Returns a TICKET {ok prev ?sem?}:
#   ok   = 1 when the viewer's context is current, 0 when the switch was REFUSED
#          (landmine 17: `new_schematic switch` silently no-ops while the current
#          context's semaphore is raised, so it must be VERIFIED, never assumed).
#   prev = the win_path to restore, or {} when there is nothing to undo — either
#          because the viewer was ALREADY current (the switch never happened, so
#          no title was clobbered) or because the switch was refused.
#   sem  = present ONLY on the issue-0314 retry below: the callback frame's own
#          semaphore, which leave_ctx must put back after the restore. Absent on
#          every other ticket, so `lindex $ticket 2` is {} and leave_ctx does
#          nothing — the two-element tickets of every older caller still work.
# Callers must bail out on ok==0 and must hand the whole ticket to leave_ctx.
#
# `borrow` OPTS IN to the issue-0314 retry, and it is opt-in for a measured
# reason (review finding, verified in the source): **`semaphore == 1` does not
# identify a gesture frame.** Three other brackets in this tree sit at exactly 1
# — `ase::wait` (src/ase.tcl:646) holds it across a `vwait` that pumps the whole
# event loop, `destroy_all_windows` (src/xinit.c:2482) raises it around a
# `tk_messageBox` "to avoid context switches when dialog below is shown", and a
# menu-driven `place_symbol` holds it with a placement in flight. Only the two
# read-only registry readers below pass `borrow 1`; `in_ctx` (whose body is
# caller-supplied and runs at `uplevel #0`) and `readout_refresh` keep the
# refusal they have always had, so an arbitrary script can never move the
# context out from under one of those brackets. Identifying the frame POSITIVELY
# would need callback.c to export one (see the receipt's follow-up note); until
# it does, the narrow door is the one that is safe to open.
proc wviewer::enter_ctx {token {borrow 0}} {
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
  if {[wviewer::switch_ctx $token]} { return [list 1 $prev] }
  # --- issue 0314: A GESTURE'S OWN CALLBACK FRAME IS WHY THAT REFUSED ---------
  #
  # ⚠⚠ EVERY KEY AND BUTTON GESTURE HOLDS THE SEMAPHORE FOR ITS WHOLE DURATION.
  # `callback()` (src/callback.c ~9098) does `xctx->semaphore++` on entry "to
  # recognize recursive callback() calls", and `switch_window`/`switch_tab`
  # (src/xinit.c ~1843/~1897) refuse outright on `if(xctx->semaphore)`. So a
  # loan taken from INSIDE a gesture — which is every Ctrl-Alt-V, every
  # binding-driven browser refresh — was refused 100% of the time, while the
  # identical call typed into the CIW (no callback frame, semaphore 0) worked.
  # That is the whole of issue 0314: the two routes disagreed, and the refusal
  # was invisible because a refused loan answers {} exactly like an empty
  # registry. MEASURED at a real gesture: `sem=1`, refusal C (switch_ctx), with
  # the same call answering 2 databases at `sem=0` one statement later.
  #
  # ⚠ ONLY `sem == 1`, AND ONLY FOR A CALLER THAT ASKED (`borrow`). `>= 2` is
  # callback.c's own busy convention (a recursive callback, a modal dialog
  # opened from inside a gesture, a placement in flight — see its ~20
  # `if(xctx->semaphore >= 2) break;` guards) and keeps the refusal it has
  # always had; `== 1` is necessary but NOT sufficient to mean "a gesture frame"
  # (see the `borrow` note above the proc), which is why the door is opened per
  # caller rather than per value. A lowered semaphore is safe for the two
  # callers that pass it because their bodies (a) run no `update`/`after`, so no
  # foreign event can interleave, (b) only READ, and (c) always restore.
  #
  # ⚠ `xschem set semaphore` IS THE LEVER THE C SIDE USES FOR THIS EXACT JOB:
  # `int save = xctx->semaphore; xctx->semaphore--; ... xctx->semaphore = save;`
  # around `open_sub_schematic` (callback.c ~6637, "so semaphore for current
  # context wll be saved correctly"). The semaphore is a PER-CONTEXT field
  # (`Xschem_ctx.semaphore`), so switch_window's save_ctx/restore_ctx carries
  # the lowered value with the design context and leave_ctx has to put it back
  # — hence the third ticket element rather than a restore right here.
  if {!$borrow} { return {0 {}} }
  set sem 0
  catch {set sem [xschem get semaphore]}
  if {$sem != 1} { return {0 {}} }
  catch {xschem set semaphore 0}
  if {![wviewer::switch_ctx $token]} {
    # still refused: some other cause (a busy target, a dying window). Put the
    # frame's semaphore back before returning — the caller is bailing out, and a
    # frame that returns to callback() one short would decrement it to -1.
    catch {xschem set semaphore $sem}
    return {0 {}}
  }
  return [list 1 $prev $sem]
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
  set sem [lindex $ticket 2]              ;# issue 0314: only the retry sets this
  if {$prev eq {}} { return 1 }           ;# never switched -> nothing to undo
  set ok 0
  catch {xschem new_schematic switch $prev}
  catch {set ok [expr {[xschem get current_win_path] eq $prev}]}
  # --- issue 0314: THE BORROWED SEMAPHORE GOES BACK UNCONDITIONALLY -----------
  #
  # ⚠⚠ TO WHICHEVER CONTEXT WILL RECEIVE THE FRAME'S DECREMENT, which is the
  # CURRENT one — not necessarily `prev`. The owning frame ends in
  # `xctx->semaphore--` (callback.c) against whatever context is current at that
  # moment, so the value has to be waiting THERE or the count goes negative.
  # Normally the restore lands and current == prev, which is the whole point of
  # the bracket. When the restore is REFUSED — `get_tab_or_window_number(prev)`
  # gone, or `Tk_NameToWindow` NULL because the window the gesture came from was
  # torn down during the loan (src/xinit.c ~1852/~1866; the file already treats
  # that as a live state and counts it) — we are stranded in the viewer, and
  # gating the restore on `$ok` would leave BOTH contexts wrong: `prev` short by
  # one and the viewer about to be decremented to **-1**, which reads as a
  # permanently raised semaphore and would refuse every context switch that
  # viewer is ever asked for again. A review pass found that hole; this is why
  # the condition is on `$sem`, never on `$ok`.
  # (Silent, like the refused restore beside it: every caller rides a keystroke
  # or the motion pump, and the event is already counted in ctx_restore_refused.)
  if {$sem ne {} && $sem ne {0}} { catch {xschem set semaphore $sem} }
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

# --- SIGNAL SEARCH: the shared matcher + the signal inventory ---------------
# (signal browser batch items 1 and 2)
# doc/claude/signal_browser_batch/PLAN.md items 1-2 + settled decisions 2/3/4/6/7;
# references/viva_cadence_waveform_viewer.md §3.2 (the search bar) and §3.3
# (wildcard semantics). Unit-testable headless
# (tests/headless/test_wave_sigsearch.tcl).
#
# THE SECTION HAS TWO HALVES, and they are NOT alike:
#
#  * the MATCHER half — `sig_type`, `sig_match` (item 1) — is PURE: no Tk, no
#    `xschem`, no ctx. Argument in, value out.
#  * the INVENTORY half — `sig_bare`, `sig_split`, `signal_entry`,
#    `signal_list` (item 2) — is pure EXCEPT for `signal_list`, which is the
#    one ctx-touching accessor in this section: it brackets a
#    `xschem raw list` read with enter_ctx/leave_ctx. Everything else here
#    stays pure, deliberately, so the split/classify rules stay testable
#    without a context.
#
# THE ONE matcher. Every consumer — the legacy Graph "signals" dialog (item 3),
# the search bar (item 4), the Add Trace picker (item 5), the browser sidebar
# (items 8+) — calls this. Nothing else may re-implement matching; that is the
# whole point of putting it here rather than in a dialog proc. Same rule for
# `signal_list`: nothing else may open-code `split [xschem raw list] "\n"`.
# (Three such sites still exist at :2566, :6798 and :7458 — items 3 and 5
# retire them; item 2 deliberately retires none, so that the accessor lands
# with zero blast radius.)

# Classify a raw signal name: `v` | `i` | `other`, on a leading `v(` / `i(`,
# case-insensitively. Used by sig_match's `-type` filter.
#
# THE SUBJECT IS THE FULL RAW NAME (settled decision 2) — `v(out)`, never the
# stripped `out`. That is exactly why the type filter can exist at all: the
# legacy `graph_get_signal_list` (xschem.tcl:4480) strips the `v(...)` wrapper
# before matching, which destroys the very prefix this classifier reads.
#
# ⚠ DELIBERATE DIVERGENCE, flagged for item 9's type dropdown: ngspice's
# `@m.x1.m1[id]` terminal-current form classifies `other` HERE, because item 1's
# contract says "classifying on a leading `v(` / `i(`" and this implements the
# contract verbatim. The neighbouring `ase::ui::output_kind`
# (src/ase_window.tcl:791) calls a leading `@` `current`. So two classifiers in
# this codebase disagree about `@`, on purpose and visibly (check ST05 pins it).
# A real raw carries @-form currents, so a user picking "Current" in item 9's
# dropdown will not see them — item 9 decides whether to widen this or not.
proc wviewer::sig_type {name} {
  if {[string match -nocase {v(*} $name]} { return v }
  if {[string match -nocase {i(*} $name]} { return i }
  return other
}

# wviewer::sig_match  siglist  pattern  ?opts?
#   -syntax   shell|regexp    default shell
#   -case     0|1             default 0  (0 = case-INsensitive, ViVA default)
#   -type     all|v|i|other   default all
#   -sort     0|1|-1          0 = raw order (default), 1 = -increasing, -1 = -decreasing
#   -key      <cmd prefix>    default {} = IDENTITY (two-pane item 20)
# Returns: {ok  {matched names...}}   on success
#          {err {message}}            on an invalid regexp
# Matching is WHOLE-NAME anchored. shell -> `string match`; regexp -> `^(?:$pat)$`.
# The subject is the FULL raw name (`v(out)`), never the stripped form.
# An empty pattern matches everything (that is a cleared box, not a typo).
#
# (contract block above is verbatim from the PLAN; the three notes below are
# additions the implementation forces:)
#
# * `siglist` is a Tcl LIST, not a newline blob. Splitting `xschem raw list` is
#   the CALLER's job (`split [xschem raw list] "\n"`) — item 2's `signal_list`
#   becomes the one place that does it.
# * The pattern is NEVER trimmed and NEVER eval'd. It is passed as data to
#   `string match` / `regexp` only, so a leading `-` or a `[` cannot become an
#   option or a command substitution. (`--` guards the regexp arm; the shell arm
#   is safe by arity — `string match $pat $n` is objc==3 and parses no options.)
# * The `^(?:...)$` wrapper makes two Tcl-only regexp forms an ERROR that would
#   compile raw: ARE directors (`***=foo`) and embedded options (`(?i)x`) are
#   legal only at the very START of an RE, so wrapped they raise "quantifier
#   operand invalid". That surfaces as an ordinary `{err ...}`, which is the
#   right shape — but it means `(?i)foo` gets an error instead of a
#   case-insensitive match. Acceptable: `-case`/the Match-case box is the
#   supported way to ask for that. Do not file it as a bug.
#
# An invalid regexp is an ERROR (settled decision 4). It must NOT degrade into
# the legacy `if {$err} {set pattern {}}` of xschem.tcl:4478, which widens a
# typo into "show everything" — the worst possible failure for a search box.
#
# --- TWO-PANE ITEM 20: `-key`, THE MATCH SUBJECT ------------------------------
#
# `-key` is a command prefix applied to each element before the PATTERN is
# tested; the ORIGINAL element is what gets returned. `{}` — the default, and
# what every pre-item-16 caller passes by omission — is the identity, so this
# option adds an ability without changing a single existing answer.
#
# ⚠⚠ THAT LAST SENTENCE IS A CLAIM THE TESTS VERIFY, NOT AN ASSUMPTION.
# `GSO01`-`GSO06` (test_wave_sigsearch.tcl) is a differential property oracle: a
# FROZEN copy of the pre-retrofit `graph_get_signal_list` run against the live
# one over 52 names x 94 patterns x 2 sorts = 10,340 comparisons with ZERO
# permitted differences, and any SEMANTIC change in here reds it. Adding an
# option that defaults to identity is the cheapest true way to give the signal
# browser's two bars a different match subject, and it is why item 20 added a
# key rather than rewriting this loop. SM29/SM30 pin the option itself.
#
# ⚠ `-type` IS NOT KEYED, DELIBERATELY. See the ⚠ on the type line in the loop.
#
# ⚠ `eval $key [list $n]`, NEVER `{*}$key $n`: this codebase targets Tcl 8.4
# upwards and `{*}` is 8.5. `[list $n]` is what stops a name containing spaces
# or brackets from being re-parsed as extra words.
#
# ⚠ `-key` IS NOT VALIDATED in the option switch below, and that is not
# laziness: a command prefix is only checkable by running it, and running it
# there — once, on nothing — would be a second call shape every key's author has
# to survive. A key that is not a command throws on the FIRST element, inside
# the caller's own catch, naming itself. Both production callers pass a literal
# proc name, so the reachable failure is a typo at edit time.
# (And it must stay a bare `-key { set key $v }` arm: a comment BETWEEN switch
# arms is parsed as a PATTERN — "extra switch pattern with no body" — which is
# how this note ended up here rather than there.)
proc wviewer::sig_match {siglist pattern args} {
  # Defaults. `nocase 1` IS decision 6's case-INsensitive default; the `-case`
  # option is its INVERSE, so it is validated as a boolean before inverting
  # (a junk value must throw cleanly here, not inside `expr`).
  set syntax shell
  set nocase 1
  set type   all
  set sort   0
  set key    {}
  if {[llength $args] % 2} {
    return -code error "wviewer::sig_match: options must come in -opt value pairs"
  }
  foreach {o v} $args {
    switch -exact -- $o {
      -syntax { set syntax [string tolower [string trim $v]] }
      -case {
        if {![string is boolean -strict $v]} {
          return -code error "wviewer::sig_match: -case wants a boolean, got \"$v\""
        }
        set nocase [expr {[string is true -strict $v] ? 0 : 1}]
      }
      -type   { set type [string tolower [string trim $v]] }
      -sort   { set sort $v }
      -key    { set key $v }
      default { return -code error "wviewer::sig_match: unknown option $o" }
    }
  }
  if {[lsearch -exact {shell regexp} $syntax] < 0} {
    return -code error "wviewer::sig_match: -syntax wants shell|regexp, got \"$syntax\""
  }
  if {[lsearch -exact {all v i other} $type] < 0} {
    return -code error "wviewer::sig_match: -type wants all|v|i|other, got \"$type\""
  }
  # Sort the INPUT, as the legacy dialog does — for a pure filter that is the
  # same result as sorting the output, and it keeps "raw order" honest.
  # The `--` is REQUIRED: `-1` is a legal value and would otherwise be eaten as
  # a switch option.
  switch -exact -- $sort {
    0  { }
    1  { set siglist [lsort -increasing -dictionary $siglist] }
    -1 { set siglist [lsort -decreasing -dictionary $siglist] }
    default { return -code error "wviewer::sig_match: -sort wants 0|1|-1, got \"$sort\"" }
  }
  # Compile + validate the regexp ONCE, up front, on the WRAPPED pattern —
  # wrapping never masks a compile error, so this is the only validation point.
  set rx {}
  if {$syntax eq {regexp} && $pattern ne {}} {
    set rx "^(?:$pattern)\$"
    if {[catch {regexp -- $rx {}} e]} { return [list err $e] }
  }
  set out {}
  foreach n $siglist {
    # ⚠⚠ THE TYPE FILTER READS THE RAW ELEMENT, NEVER `key(element)`, AND THAT
    # IS A RULING (item 20 §4.1). `sig_type` classifies on the leading `v(` /
    # `i(`, which the browser's R8 label deliberately DESTROYS — `i(v1)` renders
    # `v1:i`, whose sig_type is `other`. Key this line too and the Voltage and
    # Current dropdowns select NOTHING, everywhere, while every pattern check
    # stays green. SM30 pins both directions.
    if {$type ne {all} && [wviewer::sig_type $n] ne $type} { continue }
    # MANDATORY short-circuit: "an empty pattern matches everything" is CODED,
    # not a consequence — `string match {} x` is 0 and `regexp {^(?:)$} x` is 0.
    # It is also why the key is computed BELOW it: a cleared bar must not pay
    # for a transform whose answer it would then throw away, and this loop runs
    # once per signal on every keystroke.
    if {$pattern eq {}} { lappend out $n ; continue }
    # item 20: the pattern is tested against `key(element)`; `lappend out $n`
    # below still appends the ORIGINAL. Returning `$k` instead is the sabotage
    # that puts un-plottable strings into every gesture downstream.
    set k $n
    if {$key ne {}} { set k [eval $key [list $n]] }
    # ⚠⚠ RULING F4b — IN SHELL SYNTAX, TYPING EXACTLY WHAT THE PANE DRAWS ALWAYS
    # FINDS IT. The glob is tried first and its meaning is UNCHANGED; an EXACT
    # whole-subject equality is tried second, so the match set can only GROW.
    #
    # WHY. Item 20 made the subject the LABEL the lower pane draws, and a label
    # can legitimately contain a glob metacharacter: a bus bit renders `count[0]`
    # (RULING F4 stopped the index being eaten into `count:3`), and an ngspice
    # design net `v(x1.count[3])` has rendered `count[3]` since item 20 shipped.
    # MEASURED, before this arm: with the label as the key, `sig` found
    # `m.sub.sig` and `count` found `m.sub.count`, but `count[0]` — the exact
    # string on screen — found NOTHING, because `[0]` is read as a character
    # class. On a digital database that is the MAJORITY of names.
    #
    # ⚠ WHY NOT QUOTE THE METACHARACTERS, which is the obvious other fix.
    # MEASURED: quoting them in the subject reds SM07, whose whole subject is
    # that `[[]` is the escape for a literal `[` — `*net_name[[]*` then finds
    # nothing. Quoting them in the pattern destroys every wildcard. Both change
    # what a glob MEANS; this arm does not. SM06 (`net[0-9]` is a range), SM07
    # and SM19 (a lone `[` is a no-match, not an error) all still hold, because
    # no signal is literally named `net[0-9]` or `[`.
    #
    # ⚠ SHELL ONLY. `-syntax regexp` is the explicit power-user mode where a
    # metacharacter is what the user came for, and it keeps `count\[0\]` as the
    # exact-match escape hatch.
    if {$syntax eq {shell}} {
      if {$nocase} {
        if {[string match -nocase $pattern $k] || \
            [string equal -nocase $pattern $k]} { lappend out $n }
      } else {
        if {[string match $pattern $k] || \
            [string equal $pattern $k]} { lappend out $n }
      }
    } else {
      if {$nocase} {
        if {[regexp -nocase -- $rx $k]} { lappend out $n }
      } else {
        if {[regexp -- $rx $k]} { lappend out $n }
      }
    }
  }
  return [list ok $out]
}

# --- item 2: the typed signal inventory --------------------------------------
# PLAN item 2. `wviewer::signal_list {token}` is THE accessor every consumer
# uses instead of open-coding `split [xschem raw list] "\n"`.

# Strip ONE `<fn>(...)` wrapper: `v(x1.x2.net5)` -> `x1.x2.net5`.
#
# ⚠ FOR path/leaf SPLITTING ONLY. The `name` field of a signal_list entry is
# ALWAYS the full raw name (settled decision 2), and the type filter still
# reads the `v(`/`i(` prefix off the full name via sig_type. Nothing here
# feeds sig_match.
#
# DECLARED DIVERGENCE from the PLAN's contract line, which reads
# "leaf <last dot-segment> path <all but last>". Taken literally against the
# FULL raw name, `v(x1.x2.net5)` splits into path `v(x1` and leaf `net5)` —
# so item 8's hierarchy tree would grow a node literally called `v(x1`.
# Unwrapping first gives `x1.x2` / `net5`, which is the tree the user means.
# See doc/claude/signal_browser_batch/receipts/02_receipt.md.
#
# The trailing `$` anchor is load-bearing: `v(a)b` has no wrapper to strip and
# must come back unchanged.
proc wviewer::sig_bare {name} {
  if {[regexp {^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$} $name -> inner]} { return $inner }
  return $name
}

# {class rest} for an UNWRAPPED raw name: strip ngspice's device-class tag.
# `class` is {} when the name carries no tag, in which case `rest` is the input
# unchanged. Issue 0217; spec doc/claude/specs/waveform_signal_browser_two_pane.md §3.1.
#
# ngspice tags an object with its device class -- and ONLY when the object lives
# INSIDE a subcircuit. The same raw carries bare `i(v1)` for a top-level source
# but `i(v.x1.v1)` for one inside `x1`; the prefix exists only to reach inside.
# Left in place it becomes a hierarchy level, so the tree grows top-level nodes
# (`m`, `v`, `@m`, ...) that exist in no design. MEASURED across 22 real
# ngspice-46 raws: 2026 of 2338 hierarchical signals -- 87% -- sat under one.
#
# ⚠ THE RULE IS SOUND BY SPICE GRAMMAR, NOT BY HEURISTIC, and that is the whole
# reason it is safe to apply unconditionally. A hierarchy level in a raw name
# comes from a SUBCIRCUIT INSTANCE, and SPICE requires those to begin with `X`.
# A one-letter segment therefore CANNOT be a subckt instance -- `m...` parses as
# a MOSFET, not a subckt call. Corroborated over the corpus: all 85 distinct
# real path segments start with `x`; every fake root matches `^@?[a-z]$`; zero
# overlap. Pinned by DC13, which is the check that proves the rule does not
# over-reach (`xm.x1.foo` is a REAL instance and must survive intact).
#
# ⚠ THE `>= 2 FOLLOWING SEGMENTS` GUARD IS LOAD-BEARING (DC09). `m.foo` is
# ambiguous, and stripping it would leave an EMPTY path -- filing a signal at
# the root that belongs one level down. Total segments must be >= 3.
#
# ⚠ CASE-INSENSITIVE (DC12). ngspice lowercases, but a hand-written or foreign
# raw need not, and a case-sensitive match would pass the tag through as a
# hierarchy level -- the exact defect, one case-fold away.
#
# Declared residual risk, stated rather than defended against: a top-level NET
# named `m` cannot collide (nets carry no dots) and a subcircuit instance named
# `m` cannot exist (SPICE grammar). The only way to defeat the rule is a
# non-SPICE producer writing a raw with a one-letter hierarchy level.
proc wviewer::sig_declass {bare} {
  set parts [split $bare .]
  if {[llength $parts] < 3} { return [list {} $bare] }
  set head [lindex $parts 0]
  if {![regexp {^@?[A-Za-z]$} $head]} { return [list {} $bare] }
  return [list $head [join [lrange $parts 1 end] .]]
}

# --- spec §F, RULING F4: A DIGITAL DATABASE IS A DIFFERENT NAMESPACE ---------
#
# PURE. Is this results database's `sim_type` a DIGITAL (event) database?
# `vcd_read()` stamps `raw->sim_type` with the literal "vcd" itself
# (src/vcd_read.c:831, DECISION C6), and it is the ONLY reader that does -- so
# the engine's own answer to "what kind of database is this" is the whole test.
# `-nocase` because a hand-seeded inventory is a legal caller and the string is
# the engine's, not a user's.
#
# ⚠⚠ WHY THE CLASSIFIER HAS TO BE TOLD, AND CANNOT SNIFF THE NAME. `sig_declass`
# is sound BY SPICE GRAMMAR and by nothing else: a one-letter path segment cannot
# be a subcircuit instance because SPICE requires those to begin with `X`. A VCD
# is not SPICE. Verilog places no such rule on a module or instance name, so a
# top-level `$scope module m` is legal and produces `m.sub.sig` -- which the
# SPICE rule strips, filing a real digital wire as a MOSFET internal node.
# MEASURED on a two-scope VCD before RULING F4 landed, all three at once:
#   class devnode (wrong), path `sub` (the `m` level DELETED from the tree),
#   label `sig:i` (a wire rendered as a current), and -- because `devnode` is
#   what Ruling B's `Show device internals` box hides BY DEFAULT -- the signal
#   vanished from the browser entirely, leaving `time` alone in the tree.
# Deleting real digital data is the one outcome the 0217 rulings forbid: the two
# panes RELOCATE noise, they never delete signal.
proc wviewer::db_is_digital {dbtype} {
  return [expr {[string equal -nocase [string trim $dbtype] vcd] ? 1 : 0}]
}

# A device-class TAG -> the signal's class. PURE, and the ONLY classifier.
#
# ⚠ IT KEYS ON THE TAG, NEVER ON THE LEAF'S SHAPE, and DC25 is what forces
# that. Issue 0217:44 records "100% of device leaves contain `#`" -- true
# FORWARD, FALSE BACKWARD: six REAL design nets end in `#` (xschem's
# auto-generated net names, e.g. `v(x2.x1.a_27_47#)` in tb_charge_pump). A
# classifier keyed on "the leaf contains #" misfires on every one of them.
#
#   {}   net        a design net, or a TOP-LEVEL source's branch current
#   v    srcbranch  the branch current of a source INSIDE a subcircuit
#   @X   devmeas    a device PARAMETER accessor (@m @c @r @b @q)
#   X    devnode    a device INTERNAL NODE (m, n)
#
# ⚠ THE FIFTH VALUE, `digital`, IS NOT MINTED HERE (RULING F4). It has no tag to
# key on -- it is decided by the DATABASE a name came from, one level up in
# `signal_entry`, which is the only place that fact is in hand. Keying it here
# would mean guessing from the name's shape, which is the mistake this proc's
# own ⚠ above exists to forbid.
proc wviewer::sig_class {tag} {
  if {$tag eq {}}                       { return net }
  if {[string match {@*} $tag]}         { return devmeas }
  if {[string equal -nocase $tag v]}    { return srcbranch }
  return devnode
}

# {path leaf} for a raw signal name, split on the LAST dot of the UNWRAPPED,
# DECLASSED form. A name with no dot is all leaf and an empty path (a top-level
# signal).
#
# ⚠ RULING 14 STILL HOLDS, with one amendment: `path`/`leaf` still split the
# UNWRAPPED name -- the class strip is a step BEFORE the split, not instead of
# it. Ruling 14 exists so the tree never grows a root node called `v(x1`; the
# strip exists so it never grows one called `m` either.
#
# ⚠ RULING F4's SECOND AMENDMENT: `dbtype` is OPTIONAL and DEFAULTS TO ANALOG,
# and that shape is load-bearing rather than a style choice. Every existing
# caller and every DC/SB check passes one argument and must keep meaning exactly
# what it meant; only a caller that HOLDS a results database can answer "digital",
# and for those the declass step is SKIPPED entirely -- a VCD scope named `m` is a
# real hierarchy level, not ngspice's MOSFET tag. See `db_is_digital`.
proc wviewer::sig_split {name {dbtype {}}} {
  set bare [wviewer::sig_bare $name]
  if {![wviewer::db_is_digital $dbtype]} {
    set bare [lindex [wviewer::sig_declass $bare] 1]
  }
  set parts [split $bare .]
  if {[llength $parts] < 2} { return [list {} $bare] }
  return [list [join [lrange $parts 0 end-1] .] [lindex $parts end]]
}

# ONE raw name -> the item-2 dict {name type leaf path class}.
# `type` comes from wviewer::sig_type — never re-implemented here, so the
# browser's type dropdown and the matcher's -type filter can never disagree.
#
# ⚠ THE TAG IS CAPTURED HERE, WHERE IT STILL EXISTS. The declass step is
# DESTRUCTIVE: once the leading `m.` / `@m.` / `v.` is gone the path reads
# `x1.x1.xm1` and nothing downstream can tell `xm1` -- a pcell wrapper holding
# a transistor -- from `x2`, a real subcircuit, because SPICE requires subckt
# instances to begin with `X` and so an x-prefixed segment is grammatically
# indistinguishable from one. The stripped tag is the ONLY evidence a segment
# is a device, and it exists for exactly one instant. Capturing it costs one
# dict key; re-deriving it later would mean parsing every raw name twice.
#
# ⚠ RULING F4 (spec doc/claude/specs/mixed_signal_signal_browser.md §F). A name
# that came out of a DIGITAL database is classed `digital` and is NEVER declassed:
# there is no tag to capture, because ngspice's device-class grammar does not
# reach a VCD. `dbtype` defaults to analog so that the ~thirty existing one-argument
# callers and every DC/SB/TP check keep their exact shipped meaning.
proc wviewer::signal_entry {name {dbtype {}}} {
  if {[wviewer::db_is_digital $dbtype]} {
    lassign [wviewer::sig_split $name $dbtype] path leaf
    return [dict create name $name type [wviewer::sig_type $name] \
              leaf $leaf path $path class digital]
  }
  lassign [wviewer::sig_declass [wviewer::sig_bare $name]] tag -
  lassign [wviewer::sig_split $name] path leaf
  return [dict create name $name type [wviewer::sig_type $name] \
            leaf $leaf path $path class [wviewer::sig_class $tag]]
}

# wviewer::signal_list  token  ->  list of dicts
#     {name <full raw name> type <v|i|other> leaf <last dot-segment> path <rest>}
# Returns {} when the token is unknown, when the context switch is REFUSED, or
# when the viewer's context has no raw loaded. Never throws for "nothing to
# browse" — that is an ANSWER, and it is what produces the legacy dialog's
# "no raw data loaded" note (:7455-7456 / the C arm at scheduler.c:9727, which
# raises "No raw file loaded").
#
# THE BRACKET SHAPE IS LOAD-BEARING, do not "simplify" it:
#  * enter_ctx/leave_ctx, not a bare `new_schematic switch`: switching INTO a
#    viewer is a LOAN (issue 0173) — a read must put the context back and
#    re-assert the clobbered title. wviewer::readout_refresh is the template.
#  * the `![lindex $ticket 0]` bail is landmine 17 (a refused switch silently
#    no-ops), and it is what stops this returning SOMEBODY ELSE'S raw.
#  * NOT wviewer::in_ctx: its body runs at `uplevel #0`, so a body that
#    produces a value pollutes globals.
#  * catch the body and re-raise AFTER leave_ctx: an unexpected throw must not
#    escape past the restore and leak the foreign context.
proc wviewer::signal_list {token {statusVar {}}} {
  variable windows
  # issue 0313/0314: THE EMPTY ANSWER IS AMBIGUOUS, so an optional out-var says
  # which empty it is: `ok` (the loan was taken; {} means the viewer really has
  # no signals), `refused` (the loan was refused, so this is NOT an answer about
  # the viewer at all) or `unknown` (the token names no window). Callers that
  # OVERWRITE a model with the result must consult it — treating `refused` as
  # `ok` is how a full Signal Browser gets emptied by a gesture (issue 0313).
  # Every existing caller may keep ignoring it: the return value is unchanged.
  if {$statusVar ne {}} { upvar 1 $statusVar st }
  set st unknown
  if {![dict exists $windows $token]} { return {} }
  # `1` = borrow (issue 0314): this body reads and restores, runs no update/after
  set ticket [wviewer::enter_ctx $token 1]
  if {![lindex $ticket 0]} { set st refused ; return {} }
  set st ok
  set names {}
  set code [catch {
    if {![catch {xschem raw list} rl]} { set names [split $rl "\n"] }
  } cres]
  wviewer::leave_ctx $token $ticket
  if {$code} { return -code error $cres }
  set out {}
  foreach n $names { lappend out [wviewer::signal_entry $n] }
  return $out
}

# === signal-browser PLAN item 14: the ALL-DBs REGISTRY READER =================
#
# xschem keeps EVERY raw ever read in one per-context registry,
# `xctx->extra_raw_arr[]` (src/xschem.h:1804, manipulated by `extra_rawfile()`
# in src/save.c:1225). `xschem raw list` and friends only ever see the CURRENT
# entry (the `else if(raw && raw->values)` gate, src/scheduler.c:9576), so the
# only Tcl-visible way to read a NON-current DB's inventory is to move the
# engine's current-DB pointer, read, and put it back.
#
# ⚠ THE SOURCE OF TRUTH IS THE ENGINE REGISTRY, NOT item 13's raw HISTORY
# (receipt D1). They are genuinely different sets: `rawbar_load` pushes to the
# history AND leaves the previous raw in the registry, while `attach_raw` (the
# ASE re-run path) pushes NOTHING and starts with `xschem raw clear`. A DB the
# history never recorded is still a DB the user has open, and All-DBs searches
# it.

# PURE. `xschem raw info`'s output -> {cur <int> dbs {{idx .. path .. type ..} ..}}.
# The engine prints (src/save.c:1456-1465) `<extra_idx> current` and then one
# `<i> <rawfile> <sim_type-or-<NULL>>` line per registry slot — and NOTHING AT
# ALL when no raw is loaded, which is why the empty text has to answer
# `cur -1` rather than throw.
#
# ⚠ A DELIBERATE IMPROVEMENT ON THE LEGACY PARSE. xschem.tcl:4801 reads the same
# blob as `foreach {n f t} [lrange [xschem raw info] 2 end]`, i.e. by WORD — so a
# rawfile path containing a space shifts every field after it and the listbox
# fills with garbage. Parsing per LINE, anchored, with a greedy path and a
# trailing `\S+` type, gets that case right (pinned by BD13).
# An unparseable line is SKIPPED, never fatal: this rides the browser refresh
# path, which must not throw.
proc wviewer::rawinfo_parse {text} {
  set cur -1
  set dbs {}
  foreach line [split $text "\n"] {
    if {[regexp {^\s*(\d+)\s+current\s*$} $line -> n]} { set cur $n ; continue }
    if {[regexp {^\s*(\d+)\s+(.*\S)\s+(\S+)\s*$} $line -> n p t]} {
      lappend dbs [dict create idx $n path $p type $t]
    }
  }
  return [dict create cur $cur dbs $dbs]
}

# PURE. The tree header text for one results database: the FILE TAIL plus the
# analysis in parentheses, e.g. `bd_a.raw (tran)`.
#
# The parens are load-bearing twice over. They disambiguate the real case of the
# SAME rawfile registered twice under two analyses (`extra_rawfile()` keys its
# switch on file AND sim_type), and they guarantee the header text can never be
# mistaken for a hierarchy segment by `browser_node_for` — a design-hierarchy
# instance name contains neither a space nor a bracket. `<NULL>`, the engine's
# spelling for "no analysis", reads as no analysis rather than as a name.
proc wviewer::db_label {path type} {
  if {$path eq {}} { return "?" }
  set t $type
  if {$t eq {<NULL>}} { set t {} }
  set tail [file tail $path]
  if {$t eq {}} { return $tail }
  return "$tail ($t)"
}

# EVERY loaded results database's inventory, current one FIRST:
#   {{idx .. path .. type .. cur 0|1 label .. names {..}} ...}
#
# ⚠ WHY THIS IS NOT `signal_list` GENERALISED (driver note (f)). signal_list's
# contract is "the current raw of this token, MUTATING NOTHING", and items 8-13
# all lean on that: no browser read has ever been able to move the user's
# current DB. All-DBs cannot be written that way — it MUST move the engine's
# current-DB pointer and put it back, which adds a failure mode signal_list does
# not have (a REFUSED restore). Keeping them separate is what stops that hazard
# leaking into the twelve existing call sites. signal_list stays the authority
# for the current DB.
#
# The 0173 bracket is signal_list's, verbatim in shape: enter_ctx, bail on a
# refused ticket, catch the whole body, leave_ctx, re-raise after the restore.
# On top of it the DB restore is ITS OWN unconditional step — a throw inside the
# scan must not leave the user looking at somebody else's raw.
#
# NOTHING here calls `update` or `after`: a redraw running while the current DB
# is swapped would draw the wrong waveforms. And nothing calls `xschem raw
# clear` — item 13's atomicity rule, inherited.
proc wviewer::signal_list_all {token {statusVar {}}} {
  variable windows
  # issue 0314: the same three-way status signal_list carries, for the same
  # reason — a `{}` from a REFUSED loan is not "the viewer has no databases",
  # and a consumer that reads it as one reports a loaded VCD as not loaded.
  if {$statusVar ne {}} { upvar 1 $statusVar st }
  set st unknown
  if {![dict exists $windows $token]} { return {} }
  # `1` = borrow (issue 0314): as signal_list, and for the same three reasons
  set ticket [wviewer::enter_ctx $token 1]
  if {![lindex $ticket 0]} { set st refused ; return {} }
  set st ok
  set out {}
  set code [catch {
    set info {}
    catch {set info [xschem raw info]}
    set pi [wviewer::rawinfo_parse $info]
    set cur [dict get $pi cur]
    if {$cur >= 0} {
      # ⚠ `here` TRACKS WHERE THE ENGINE ACTUALLY IS, and it is not decoration.
      # The first cut skipped the switch whenever `idx == cur` — correct only on
      # the FIRST iteration. After visiting a foreign DB the pointer is on THAT
      # DB, so the current DB's own turn read the previous DB's names and the
      # scan answered the same inventory twice. Caught by BD43b's per-DB names
      # leg; a check that had only counted the entries would have gone green.
      set here $cur
      set lcode [catch {
        foreach db [dict get $pi dbs] {
          set idx [dict get $db idx]
          set reached 1
          if {$idx != $here} {
            set sw 0
            catch {set sw [xschem raw switch $idx]}
            if {$sw != 1} { set reached 0 } else { set here $idx }
          }
          if {!$reached} { continue }
          set names {}
          if {![catch {xschem raw list} rl]} { set names [split $rl "\n"] }
          lappend out [dict create \
            idx   $idx \
            path  [dict get $db path] \
            type  [dict get $db type] \
            cur   [expr {$idx == $cur ? 1 : 0}] \
            label [wviewer::db_label [dict get $db path] [dict get $db type]] \
            names $names]
        }
      } lerr]
      # THE RESTORE, unconditional and outside the loop's own catch: a refused
      # switch, an empty DB or a throw all still land back on the DB the user
      # was on. Pinned by BD34.
      catch {xschem raw switch $cur}
      if {$lcode} { return -code error $lerr }
    }
  } cres]
  wviewer::leave_ctx $token $ticket
  if {$code} { return -code error $cres }
  set head {}
  set rest {}
  foreach e $out {
    if {[dict get $e cur]} { lappend head $e } else { lappend rest $e }
  }
  return [concat $head $rest]
}

# --- spec §D1: a trace may live in a DB that is NOT the current one ----------
#
# THE MECHANISM ALREADY EXISTS IN C AND IS PROVEN TO RENDER. One `node=` entry is
#
#     [alias;]<vec-or-RPN> [ '%' [<dataset-digits> ] <rawfile> [ <sim_type> ] ]
#
# and `draw_graph()` (src/draw.c:8185-8215) reacts to the `%` part by calling
# `extra_rawfile(<autoload>, <rawfile>, <sim_type>, ...)` — with `autoload`
# absent that is what-code 2, SWITCH-ONLY — drawing that one trace against that
# DB, then switching back at the end of the node iteration (draw.c:8438). So an
# analog trace and a VCD trace render in ONE strip on ONE time axis. MEASURED,
# not inferred: tests/headless/test_wave_crossdb_trace.tcl renders both to a PNG
# and probes the pixels.
#
# THE THREE RULES THE C SIDE IMPOSES ON THE STRING WE EMIT, each one measured:
#
#  1. SWITCH-ONLY means the DB MUST ALREADY BE IN THE REGISTRY, keyed on the
#     STORED FULL PATH plus the sim_type, compared with a bare `strcmp`
#     (save.c:1653-1655, inside the `what == 2` switch arm save.c:1647-1665). So
#     the `%` value has to be the path `xschem raw info` reports —
#     `wviewer::db_label` returns the file TAIL and is NOT usable here.
#     An empty sim_type is worse than useless: draw_graph substitutes the CURRENT
#     DB's type (draw.c:8194-8195), which for an analog current DB is `tran`, and
#     the VCD switch then fails silently. Hence db_suffix refuses to emit a
#     half-suffix.
#  2. Both fields are RESOLVED twice — once by node_token_split() and again
#     inside extra_rawfile() — and the sub-field separator set is "\n ", so a
#     space TRUNCATES the path and turns the remainder into the sim_type.
#     `$` IS STILL LIVE: that resolution expands Tcl variables on purpose (the
#     shipped `rawfile=$netlist_dir/...` corpus depends on it), so a literal `$`
#     in a path still means something other than itself.
#     `[` `]` `{` `}` `\` ARE NO LONGER SUBSTITUTION SYNTAX — issue 0812 replaced
#     both `subst {…}` splices with a C byte scanner (util.c
#     resolve_rawfile_path/expand_tcl_vars) that copies every byte it does not
#     recognise as a `$name`. They stay on this reject list anyway, and the
#     guard below is UNCHANGED: this proc is a conservative filter over a field
#     that also has separator and tokenizer rules (3), the viewer never needs
#     such a path, and a false reject costs a suffix while a false accept costs
#     a silently mis-parsed field. `~/` IS expanded in this field: an earlier
#     revision of this line said it was not, and that was wrong --
#     node_token_split() (draw.c) resolves the `%` rawfile field with
#     resolve_rawfile_path(), which calls expand_tilde() before extra_rawfile()
#     ever sees it. `~` is not on the reject list below and does not need to be.
#     Because the field is resolved TWICE, a variable whose VALUE contains a `$`
#     expands on the second pass and the entry then keys off a path that a
#     one-pass `xschem raw clear` cannot match — issue 0820.
#  3. `%` itself is the field separator (find_nth(...,"%",...)), and `"` is the
#     quote char of the tokenizer — neither can appear inside the value.
#
# WHAT THIS USED NOT TO BUY, kept as history rather than deleted: when this block
# was written only THREE of the six functions that walk `node=` honoured
# `%rawfile`, so a cross-DB trace RENDERED and was then not pickable, not
# boldable and not markable — issue
# doc/claude/issues/0305-per-trace-rawfile-is-honoured-by-three-of-six-node-walkers.md.
# All SEVEN walkers now go through one node_token_split() (batch F items 1 and 2),
# and the seventh — graph_fullxzoom(), which never parsed `%` at all, so an auto X
# window spanned the current DB's extent only — joined them in batch F item 8:
# the automatic X window is now the UNION of the extents of every database
# contributing a trace to the shared-X strip group (spec §D2,
# doc/claude/specs/mixed_signal_signal_browser.md, "D2 — the joint X domain").
# Deliberately still NOT unioned, per RULING D2-4: `sim_type=` gates X
# propagation, so a rect tagged `sim_type=vcd` does not X-follow one tagged
# `sim_type=tran`. graph_props emits one sim_type per session, so the viewer does
# not hit that today — a mixed strip is a single rect.

# PURE: may `$s` be carried inside a `node=` `%` suffix at all? See rules 2 and 3
# above. Rejects the empty string too — a suffix field that is empty is never a
# valid switch key.
proc wviewer::db_path_safe {s} {
  if {$s eq {}} { return 0 }
  # whitespace (field separator), % (field separator), " (tokenizer quote),
  # $ (still live: variable expansion, by design), and backslash + [ ] + braces,
  # which stopped being substitution syntax with issue 0812 but stay rejected as
  # a conservative filter — see rule 2 above.
  if {[regexp {[][{}%\"\\$[:space:]]} $s]} { return 0 }
  return 1
}

# PURE: the `%<rawfile> <sim_type>` suffix a trace dict earns, or {} for the
# ordinary current-DB trace (which must keep serialising byte-identically to
# pre-§D1 — that is what keeps the 127 shipped schematics with embedded graphs
# and every existing viewer test unchanged).
proc wviewer::db_suffix {tr} {
  set rf [wviewer::dget $tr rawfile {}]
  set st [wviewer::dget $tr sim_type {}]
  if {![wviewer::db_path_safe $rf]} { return {} }
  if {![wviewer::db_path_safe $st]} { return {} }
  # `<NULL>` is how `xschem raw info` SPELLS "this slot has no sim_type"
  # (save.c:1780), and `extra_rawfile()`'s switch arm skips any slot whose
  # `sim_type` is NULL before it ever compares (save.c:1653). A `%path <NULL>`
  # suffix is therefore a suffix that can never switch — the same silent blank
  # the half-suffix rule above exists to prevent, one spelling further out.
  if {$st eq {<NULL>}} { return {} }
  return "%$rf $st"
}

# Which loaded DB holds signal `vec`? Returns {} when NO registered database has
# it, else `{idx .. path .. type .. cur 0|1 label ..}`.
#
# THE CURRENT DB WINS: signal_list_all yields the current database first, so a
# name present in both resolves to the current one and earns no suffix. That is
# deliberate — it is what makes this proc a pure ADDITION to add_trace rather
# than a change of behaviour for every existing single-DB trace.
#
# The match rule is validate_rpn's, verbatim: case-insensitive, and a bare `x`
# also matches a stored `v(x)` (get_raw_index's own probe ladder does the same on
# the C side, save.c). lsearch over the split list is the C-speed form; this proc
# is only ever reached after the CURRENT DB has already refused the name.
proc wviewer::resolve_signal_db {token vec} {
  set lv [string tolower $vec]
  foreach db [wviewer::signal_list_all $token] {
    set names {}
    foreach n [dict get $db names] { lappend names [string tolower $n] }
    if {[lsearch -exact $names $lv] < 0 && [lsearch -exact $names "v($lv)"] < 0} { continue }
    return [dict create idx [dict get $db idx] path [dict get $db path] \
                        type [dict get $db type] cur [dict get $db cur] \
                        label [dict get $db label]]
  }
  return {}
}

# ONE registry slot by its INDEX, in `resolve_signal_db`'s dict shape plus the
# slot's `names`; {} when no slot has that index.
#
# ⚠ WHY AN INDEX LOOKUP EXISTS AT ALL, next to a name lookup (this is the whole
# of DEFECT 2's fix). `resolve_signal_db` answers "which DB has a signal CALLED
# this", and its documented tie-break is "the current DB wins" — right for a
# caller that has only a name (the Add Trace… dialog's text entry, a scripted
# `xschem`-level add). It is WRONG for the signal browser, whose tree row id
# ALREADY carries the database the user pointed at (`d:2|s:TOP.m.sig`): with the
# same name in two VCDs, the name-only rule silently plots blockA's waveform
# under the row the user clicked in blockB's pane. So the browser resolves by
# INDEX and decision 4 keeps holding, unchanged, for every name-only caller.
proc wviewer::db_by_index {token idx} {
  if {![string is integer -strict $idx]} { return {} }
  foreach db [wviewer::signal_list_all $token] {
    if {[dict get $db idx] != $idx} { continue }
    return [dict create idx [dict get $db idx] path [dict get $db path] \
                        type [dict get $db type] cur [dict get $db cur] \
                        label [dict get $db label] names [dict get $db names]]
  }
  return {}
}

# PURE: the FOREIGN databases a restored/loaded layout's traces NAME, as
#   {{path .. type .. vecs {..}} ...}
# — one entry per distinct `{rawfile sim_type}` pair, in first-appearance order,
# each carrying the vecs that need it (so a failure can name what goes blank).
#
# ⚠ THIS IS DEFECT 1's ORACLE. `wviewer::restore` attaches ONE database (the
# session's analog raw) and then draws traces whose `node=` tokens switch to a
# database it never re-read — `extra_rawfile()`'s switch-only arm just fails, at
# `dbg(1)`, and the strip STILL LISTS the signal in its legend. The symptom is
# "that signal is flat", not "the data is gone". Deriving the list from the
# traces themselves (rather than from the ASE run's artifacts alone) is what
# makes the fix cover a hand-edited state, a saved-results seam and a non-`vcd`
# sim_type as well as the ordinary co-sim reopen.
#
# Only pairs that CAN be carried in the `%` grammar are returned: a pair
# db_suffix would refuse never reaches `node=` in the first place, so re-reading
# it would attach a database nothing can switch to.
proc wviewer::trace_dbs {graphs} {
  set out {}
  set seen {}
  foreach G $graphs {
    foreach tr [wviewer::dget $G traces {}] {
      if {[wviewer::db_suffix $tr] eq {}} { continue }
      set p [wviewer::dget $tr rawfile {}]
      set t [wviewer::dget $tr sim_type {}]
      set v [wviewer::dget $tr vec {}]
      set k [list $p $t]
      set at [lsearch -exact $seen $k]
      if {$at < 0} {
        lappend seen $k
        lappend out [dict create path $p type $t vecs [list $v]]
      } else {
        set e [lindex $out $at]
        dict set e vecs [concat [dict get $e vecs] [list $v]]
        set out [lreplace $out $at $at $e]
      }
    }
  }
  return $out
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
# --- item 7: the DESTINATION argument -----------------------------------------
# `dest` (append|replace|newstrip|newtab, settled item 7) is the LANDING half of
# the plot-destination policy; the WINDOW half — anything that must happen before
# this proc can speak, which today is exactly "make the new tab" — lives in
# wviewer::dest_prepare and has already run by the time we get here.
#
# ⚠ `newtab` BEHAVES AS `append` INSIDE plan_plot, AND THAT IS NOT A BUG. By the
# time plan_plot is called for a New Tab gesture, dest_prepare has already made
# the tab and the layout it is asked about is the NEW tab's, which holds exactly
# one empty strip — which `append` lands in. Keeping the tab-making out of this
# pure proc is what makes that true. ⚠ AND THERE IS NO `newtab` STATEMENT BELOW
# TO CREDIT IT TO: the body names only `newstrip` and `replace`, so `newtab`
# reaches the append policy BY FALL-THROUGH. (An explicit `set dest append`
# collapse used to sit here; it was MEASURED to change nothing over every
# mode/ngraphs/target/empties combination and removed, because a line that
# cannot fail reads as a guard and is not one. DS09 pins the BEHAVIOUR, which is
# what the callers depend on either way.)
#
# `append` keeps the 6-argument answer BYTE-IDENTICAL to what it has always been
# (no `clear` key at all), which is why the ~25 whole-dict comparisons in
# test_wave_modes.tcl are this extension's regression oracle.
#
# THE `clear` KEY IS EMITTED IFF dest eq replace: the list of ALREADY-EXISTING,
# NON-EMPTY landing strips the caller must empty first
# (wviewer::plan_replace_clear). Callers read it with
# `wviewer::dget $plan clear {}` — the graph_props precedent for "emit a key only
# when it means something".
#
# ⚠⚠ REPLACE IS A SINGLE-MODE POLICY, AND THAT IS STRUCTURAL, NOT AN OVERSIGHT.
# The multi arm below lands every signal either in a strip it CREATES or in a
# REUSED EMPTY strip — it never lands on an occupied one, for any destination.
# So under multi-plot there is by construction nothing for `replace` to clear:
# the `clear` key is present (the shape still tracks the destination) but it is
# ALWAYS EMPTY, and Replace is behaviourally identical to Append there. Declared,
# not fixed: making Replace mean "wipe the whole plot area" under multi would be
# a different policy from "clear the target graph's traces first", which is the
# one item 7 was given. DS05/DS05b pin it as a differential.
proc wviewer::plan_plot {mode ngraphs target n {auto -1} {empties {}} {dest append}} {
  # FIRST, and it must stay first: an empty gesture is a no-op for EVERY
  # destination — a New Tab / Replace with nothing to plot must not make a tab,
  # clear a strip or produce a `clear` key.
  if {$n <= 0} { return [dict create new 0 targets {}] }
  set dest [wviewer::dest_norm $dest]
  # (`newtab` is deliberately not named from here on — see the ⚠ above: it
  # reaches the append policy by fall-through, and DS09 pins that.)
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
  if {$dest eq {newstrip}} {
    # FORCE exactly ONE fresh strip and land the whole batch in it: the target is
    # ignored, and so is every reusable empty strip ("force a fresh graph
    # regardless of plot mode" — that is the whole point of the policy).
    # WHERE the strip goes is still the MODE's own rule, because plot_signals is
    # what inserts it and inserts BY MODE:
    #   multi  front-inserts -> the fresh strip is at post-insert index 0
    #   single appends       -> the fresh strip is at index $ngraphs
    # Choosing the index this way is what lets plot_signals' strip-creation
    # block stay COMPLETELY UNCHANGED, and it is why the New Strip check can be
    # written against a graph COUNT plus one strip's trace list.
    set gi [expr {$mode eq {multi} ? 0 : $ngraphs}]
    set t {}
    for {set k 0} {$k < $n} {incr k} { lappend t $gi }
    set plan [dict create new 1 targets $t]
  } elseif {$mode eq {multi}} {
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
    set plan [dict create new $new targets $t]
  } else {
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
      set plan [dict create new $new targets $t]
    } else {
      set t {}
      for {set k 0} {$k < $n} {incr k} { lappend t $gi }
      set plan [dict create new 0 targets $t]
    }
  }
  # ...and ONLY here does the answer's SHAPE ever change: every non-replace
  # destination returns exactly the dict this proc has always returned.
  if {$dest eq {replace}} {
    # `free` and not `$empties`: the sanitized list is the one the arms above
    # planned against, so it is the one that says which landing strips are known
    # to be empty already.
    dict set plan clear [wviewer::plan_replace_clear $mode $ngraphs $plan $free]
  }
  return $plan
}

# PURE: which of `plan`'s landing strips ALREADY EXIST **AND HOLD TRACES** —
# i.e. exactly the strips a `replace` gesture must empty before it adds. Deduped,
# ascending, in the PLAN's own index space (post-insert for multi), because that
# is the space plot_signals runs the clear loop in.
#
# `free` is plan_plot's sanitized empty-strip list, in the PRE-insert space.
#
# ⚠ THE TWO ARMS LIVE IN DIFFERENT INDEX SPACES, and getting this wrong clears
# the WRONG strip (silently — the traces just vanish from a strip nobody was
# looking at):
#   multi  -> targets are POST-INSERT (see plan_plot's contract), so the strips
#             this plan CREATES are exactly 0..new-1, and a target `t >= new` is
#             the pre-existing strip `t - new`.
#   single -> `new` is 0 or 1, and when it is 1 the single landing strip IS the
#             one just appended, so nothing pre-exists; when it is 0 the target
#             is a live strip in the UNSHIFTED space.
#
# ⚠ A BRAND-NEW **OR REUSED-EMPTY** STRIP IS NEVER LISTED, and that second half
# is why `free` is an argument at all. It is not tidiness: clear_graph_traces
# runs wavehl_remap_apply, markers_sweep_numbers and set_graphs (a redraw), so
# calling it on a strip with nothing to clear is real work with real side
# effects. Both arms reach reused-empty strips — multi always (every landing
# site it does not create is a reused empty), single whenever the target
# resolved onto one (empty stack, auto-strip target, or a target that simply is
# an empty strip). Both were listed before this filter existed, and the single
# arm's reuse path is now pinned by DS04b/DS04c.
#
# ⚠ CONSEQUENCE, DECLARED: under multi this ALWAYS returns {} — see plan_plot's
# ⚠⚠. The filter is written generally anyway, so a future multi arm that could
# land on an occupied strip gets the right answer instead of a silent no-clear.
proc wviewer::plan_replace_clear {mode ngraphs plan {free {}}} {
  set new [wviewer::dget $plan new 0]
  set out {}
  foreach t [wviewer::dget $plan targets {}] {
    if {![string is integer -strict $t]} { continue }
    if {$mode eq {multi}} {
      if {$t < $new} { continue }
      set pre [expr {$t - $new}]
    } else {
      # single: a plan that created its strip lands ONLY there
      if {$new > 0} { continue }
      if {$t >= $ngraphs} { continue }
      set pre $t
    }
    # ...and a strip that was REUSED because it was empty has nothing to clear
    if {[lsearch -exact $free $pre] >= 0} { continue }
    if {[lsearch -exact $out $t] < 0} { lappend out $t }
  }
  return [lsort -integer $out]
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
    # spec §D1: a trace that was picked from a DB OTHER than the current one
    # carries its own database in the node token — `<vec>%<rawfile> <sim_type>`.
    # THE SUFFIX MUST BE EMITTED HERE and nowhere else: regenerate rebuilds every
    # rect from this proc, and it fires on a window RESIZE, on add_trace and on
    # attach_raw, so a `%` set straight onto a rect with `xschem setprop` lives
    # exactly until the next repaint. Carrying it in the trace dict and emitting
    # it here is what makes a cross-DB trace survive.
    set sfx [wviewer::db_suffix $tr]
    if {$sfx ne {}} {
      # ALWAYS the alias form when a suffix is present. draw_graph passes the
      # WHOLE token (`%` and all) to draw_graph_variables for the legend
      # (draw.c:8247), so a bare `vec%path type` legends as the full absolute
      # path — MEASURED: the legend read
      # `TOP.m.siga%/home/qflow/dev/xschem/claude_1/...`. With the alias the
      # legend is `find_nth(ntok,";",..,1)` = the display name (draw.c:4424-4425).
      if {$nm eq {} || $nm eq $vec} { set nm $vec }
      lappend ntoks "\\\"$nm;$vec$sfx\\\""
    } elseif {$nm ne {} && $nm ne $vec} {
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
#
# `vcdfiles` (spec section E, E3) are the run's DIGITAL databases — one VCD per
# d_cosim code block, from ase::last_vcdfiles. They are read AFTER the analog
# raw and the analog raw is then made current again, because `xschem raw read`
# makes whatever it just read the current DB and every consumer downstream
# expects analog vector names there. The whole registry sequence lives in
# ase::attach_dbs so it is headless-testable; this proc keeps the ctx switch,
# the 0194 view-state capture and the regenerate. DEFAULTS TO {} — the
# three-argument call is byte-for-byte what it always was.
proc wviewer::attach_raw {token rawfile sim_type {vcdfiles {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {$rawfile eq {} || ![file isfile $rawfile]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }   ;# never clear a foreign ctx
  # issue 0194: a re-run replaces the DATA, not the plot — the strips, the
  # traces and which of them the user had selected all carry forward, so the
  # regenerate below owes the fold. skip_ranges is what keeps a fresh run
  # autozooming instead of being drawn in the outgoing run's window.
  wviewer::capture_live_view_state $token
  set att [ase::attach_dbs $rawfile $sim_type $vcdfiles]
  foreach v [dict get $att skipped] {
    catch {::ase::echo "ase: digital database not attached (missing or unreadable): $v" error}
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
# The other half of D19. `vdict` with no `tabs` key leaves the one-tab stash
# `open` seeded (and `restore`'s own flat-key writes are that tab's content),
# so old state files load exactly as they always did. With `tabs`, rebuild the
# stash from it and thaw whichever record `activetab` names.
proc wviewer::restore_tabs {token vdict} {
  variable tabstash; variable curtab; variable tabseq
  set tabs [wviewer::dget $vdict tabs {}]
  if {[llength $tabs] < 2} { return 0 }
  set recs {}
  set id 1
  foreach t $tabs {
    lappend recs [dict create id $id \
                    name [wviewer::dget $t name "Tab $id"] \
                    layout [wviewer::dget $t layout [dict create sharedx 0 graphs {}]] \
                    mode   [wviewer::dget $t mode single] \
                    target [wviewer::dget $t target 0] \
                    cva 0 cvb 0 cvr 0 undo {} redo {} wavehl {} view {}]
    incr id
  }
  set tabseq($token) $id
  set cur [wviewer::dget $vdict activetab 0]
  if {![string is integer -strict $cur] || $cur < 0 || $cur >= [llength $recs]} {
    set cur 0
  }
  set tabstash($token) $recs
  set curtab($token) $cur
  # the caller has just written the FLAT keys into the live arrays; they
  # describe the tab that was active when the state was saved, which is exactly
  # $cur -- but thaw it anyway, so a hand-edited state whose flat keys disagree
  # with tabs[activetab] resolves in favour of the tab list.
  wviewer::tab_thaw $token [lindex $recs $cur]
  wviewer::tabbar_refresh $token
  return 1
}

# PURE-ish: the whole tab list as SERIALISABLE records (no `view`, no history,
# no highlight set -- a saved layout carries the state, not the transient chrome
# or the history that produced it). The ACTIVE tab is taken from the LIVE
# arrays, the others from the stash. Deliberately does NOT call tab_freeze:
# that reads the rects and would switch the xschem context inside what the ASE
# state save expects to be a pure read.
proc wviewer::tabs_serialize {token} {
  set recs [wviewer::tab_records $token]
  if {[llength $recs] < 2} { return {} }
  set cur [wviewer::tab_index $token]
  set out {}
  set i 0
  foreach r $recs {
    if {$i == $cur} {
      lappend out [dict create name [wviewer::dget $r name "Tab [wviewer::dget $r id $i]"] \
                     layout [wviewer::layout_for $token] \
                     mode   [wviewer::plot_mode $token] \
                     target [wviewer::target_index $token]]
    } else {
      lappend out [dict create name [wviewer::dget $r name "Tab [wviewer::dget $r id $i]"] \
                     layout [wviewer::dget $r layout [dict create sharedx 0 graphs {}]] \
                     mode   [wviewer::dget $r mode single] \
                     target [wviewer::dget $r target 0]]
    }
    incr i
  }
  return $out
}

proc wviewer::snapshot {token prev} {
  if {[wviewer::window_for $token] ne {}} {
    set lay [wviewer::layout_for $token]
    # TABS (D19): the flat keys keep describing the ACTIVE tab VERBATIM, and
    # `tabs`/`activetab` are emitted ONLY when the window has two or more. So a
    # single-tab viewer serialises byte-identically to the pre-tabs one -- which
    # matters beyond compatibility: ase::ui::viewer_snapshot's difference test
    # would otherwise mark every session dirty. An older build reading a new
    # file sees the active tab and ignores `tabs`; a new build reading an old
    # file finds no `tabs` and builds a one-tab viewer. No version bump.
    set tabs [wviewer::tabs_serialize $token]
    set d [dict create open 1 \
                       sharedx [wviewer::dget $lay sharedx 0] \
                       rawfile {} \
                       graphs  [wviewer::dget $lay graphs {}] \
                       mode    [wviewer::plot_mode $token] \
                       target  [wviewer::target_index $token]]
    if {[llength $tabs]} {
      dict set d tabs      $tabs
      dict set d activetab [wviewer::tab_index $token]
    }
    # SIGNAL BROWSER (item 15): the sidebar's own state, and GATED ON BEING
    # NON-DEFAULT for exactly the reason the two tabs keys are. A window nobody
    # opened the browser in serialises byte-identically to the pre-item-15 one,
    # so `test_wave_modes.tcl` MG9's fixed key list still holds and
    # `ase::ui::viewer_snapshot`'s difference test does not mark every session
    # dirty. The gate lives in `browser_state_is_default`, which also answers 1
    # for the {} a window with no sidebar returns.
    set bs [wviewer::browser_state $token]
    if {![wviewer::browser_state_is_default $bs]} { dict set d browser $bs }
    return $d
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
#
# `dbs` (spec §D1, DEFECT 1 — 2026-08-09) is the EXTRA databases to re-attach
# beside the primary raw, as `{{path type} ...}`. `ase::ui::viewer_restore` fills
# it from `ase::last_vcdfiles`, exactly as the other two attach sites
# (`ase_window.tcl` dp_finish and auto_plot) already hand that list to
# `attach_raw`. It defaults to {} so the four-argument call is byte-for-byte what
# it always was, and it is a UNION with the databases the restored traces
# themselves name (`wviewer::trace_dbs`) — see the block below for why the second
# half is not optional.
proc wviewer::restore {token vdict rawfile sim_type {dbs {}}} {
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
  # TABS (D19): a `tabs` key rebuilds the whole stash; its absence (every state
  # file written before tabs) leaves the single tab `open` already seeded, whose
  # content the flat keys above have just overwritten. Either way the ACTIVE
  # tab's live arrays are already correct, so this only has to (a) install the
  # OTHER tabs and (b) point `curtab` at the right one -- and when `activetab`
  # is not the last record, hand the live arrays that record instead.
  wviewer::restore_tabs $token $vdict
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
    # --- spec §D1 / DEFECT 1: RE-ATTACH THE DATABASES THE TRACES NAME ---------
    #
    # ⚠⚠ WITHOUT THIS, A SAVED CROSS-DB TRACE COMES BACK SILENTLY BLANK. The
    # `raw clear` + single `raw read` above leave exactly ONE database in the
    # registry, so a trace whose `node=` token ends in `%<rawfile> <sim_type>`
    # asks `extra_rawfile()` to SWITCH to a database that is no longer there.
    # That arm just returns 0 at `dbg(1)` (save.c:1663) — the strip still LISTS
    # the signal in its legend and draws nothing, which reads as "that signal is
    # flat", not "the data is gone". MEASURED end to end in two processes:
    # `tests/headless/test_wave_crossdb_trace.tcl`'s XS* leg.
    #
    # AFTER the `raw add` loop, deliberately: `xschem raw read` makes what it
    # read CURRENT (extra_rawfile()'s read arm, save.c:1626-1627 for a fresh
    # slot and :1642-1643 when the path was already registered), and those RPN
    # vectors belong to the ANALOG raw. The switch back at the end restores it
    # for the same reason
    # `ase::attach_dbs` does — every downstream consumer (annotate_op, `xschem
    # raw value`, add_trace's own validation) resolves names against the current
    # DB and expects analog vector names there.
    #
    # THE UNION, and why both halves. `$dbs` is the RUN's digital artifacts
    # (`ase::last_vcdfiles`, the list the other two attach sites already pass) —
    # it re-attaches a co-sim run's VCDs even when no trace names them yet, so
    # the browser's All-DBs pane and the next add_trace can see them.
    # `trace_dbs` is what the RESTORED TRACES actually need — it covers a
    # hand-edited state, the saved-results seam, a `multi 1` VCD that
    # last_vcdfiles deliberately excludes, and any sim_type that is not `vcd`.
    # Neither is a superset of the other.
    set here -1
    catch {set here [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]}
    set want {}
    foreach pt $dbs {
      # `{path type}` is the contract; a ONE-WORD element is accepted as a bare
      # path (that is `ase::last_vcdfiles`' own shape) and anything else is taken
      # WHOLE as the path — a path containing a space must not be chopped at its
      # first word, which is exactly what `lindex $pt 0` would do to it.
      if {[llength $pt] == 2} { lassign $pt p t } else { set p $pt ; set t {} }
      if {$t eq {}} { set t vcd }
      if {$p eq {}} { continue }
      lappend want [dict create path $p type $t vecs {}]
    }
    foreach e [wviewer::trace_dbs [dict get [wviewer::layout_for $token] graphs]] {
      set at -1
      set i 0
      foreach w $want {
        if {[dict get $w path] eq [dict get $e path] \
            && [dict get $w type] eq [dict get $e type]} { set at $i ; break }
        incr i
      }
      if {$at < 0} { lappend want $e } else {
        set w [lindex $want $at]
        dict set w vecs [concat [dict get $w vecs] [dict get $e vecs]]
        set want [lreplace $want $at $at $w]
      }
    }
    foreach e $want {
      set p [dict get $e path]
      set t [dict get $e type]
      # the PRIMARY raw is already in the registry under exactly this key; a
      # second `raw read` of it would only switch to it (save.c:1640-1644).
      # BOTH fields must match: the same file registered under two analyses is
      # two databases (extra_rawfile() keys its switch on file AND sim_type), so
      # `{<rawfile> ac}` beside a `tran` primary is a real second attach.
      if {$p eq $rawfile && $t eq $sim_type} { continue }
      set ok 0
      if {[file isfile $p]} {
        catch {set ok [expr {[xschem raw read $p $t] eq {1}}]}
      }
      if {$ok} { continue }
      # ⚠⚠ THE DECISION: NOISY, NOT FATAL, AND NEVER SILENT.
      #
      # A hard failure here would stop the SESSION from opening over a deleted
      # scratch VCD, which is strictly worse than the bug being fixed — the
      # layout, the analog traces and everything else are still perfectly good.
      # But "silently blank" is the defect, so the one thing this must not do is
      # nothing. The message NAMES THE TRACES that will draw nothing, which is
      # precisely what tells "flat" apart from "gone" — a flat signal is not
      # listed in an error line. `wviewer::echo` is byte-for-byte `ase::echo`'s
      # shape (ciw_echo pane half + `xschem log_action`, src/wave_viewer.tcl:637
      # / src/ase.tcl:126), so this reaches the CIW AND the log file; it is used
      # instead of `ase::echo` only because a viewer need not belong to an ASE
      # session. The traces are LEFT ALONE on purpose: stripping the `%` suffix
      # would make them resolve against the analog raw and plot a DIFFERENT
      # signal, and dropping them would silently discard the user's layout on a
      # transient mount failure. Residual limitation recorded in
      # doc/claude/issues/0305-*.md.
      set vs [dict get $e vecs]
      if {[llength $vs]} {
        wviewer::echo "wviewer: results database not re-attached: $p ($t) —\
[join $vs {, }] will draw NOTHING (the data is missing, not flat)" error
      } else {
        wviewer::echo "wviewer: results database not re-attached: $p ($t)" error
      }
    }
    if {$here >= 0} { catch {xschem raw switch $here} }
  }
  wviewer::regenerate $token
  # SIGNAL BROWSER (item 15): LAST, and after the regenerate rather than before
  # it. Packing the sidebar resizes the canvas, and that already goes
  # <Configure> -> wviewer::on_configure -> configure_apply, which captures and
  # regenerates on its own (browser_toggle's ⚠) — doing it before would fold a
  # layout the window is about to be given again. An absent `browser` key (every
  # state file written before this item) makes this a no-op.
  catch {wviewer::browser_state_apply $token [wviewer::dget $vdict browser {}]}
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
#
# `db` (spec §D1 / DEFECT 2) is a REGISTRY INDEX naming the database this signal
# was picked FROM — the signal browser has it, because its tree row id carries
# it. Given one, the name is resolved in THAT database and nowhere else. `{}` is
# every caller that has only a name, and keeps decision 4 ("the current DB wins,
# then the first other DB that has the name") exactly as it was.
proc wviewer::add_trace {token gi rpn {name {}} {color {}} {db {}}} {
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
  # spec §D1: {} = "the current DB owns this trace" (the only case before §D1).
  # Set only when the name resolves in some OTHER loaded database; graph_props
  # turns it into the `%<rawfile> <sim_type>` node suffix.
  set trdb {}
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
    #
    # spec §D1: validation is against EVERY loaded database, not just the
    # current one. Before this, `$varlist` (`xschem raw list` = the CURRENT DB)
    # was the whole world, so a VCD signal was refused unless the user made the
    # VCD current — which then broke every analog trace in the window. The
    # current DB is still tried FIRST and still emits a bare vector name, so
    # nothing about an ordinary single-DB add changes.
    #
    # ⚠⚠ …UNLESS `db` NAMES ONE (DEFECT 2). An explicit index is the user's own
    # pick, made by clicking a row under a specific database's header, and it
    # OVERRIDES the name search entirely — including the "the current DB wins"
    # tie-break, which is right for a name and wrong for a pointer. An index that
    # no longer resolves (a stale row list after a `raw clear`) degrades to the
    # name search rather than refusing: the rows the user is looking at are then
    # describing a registry that has moved, and plotting the same-named signal
    # from whatever DB still has it is the lesser surprise.
    if {$rawok} {
      set hit {}
      if {$db ne {}} { set hit [wviewer::db_by_index $token $db] }
      if {$hit ne {}} {
        # THE NAMED DATABASE AND NOWHERE ELSE. A name it does not have is
        # REFUSED naming it, never quietly satisfied out of another DB — that
        # silent substitution is the whole of DEFECT 2.
        set err [wviewer::validate_rpn $rpn [dict get $hit names]]
        if {$err ne {}} {
          return "'$rpn' is not in [dict get $hit label] ($err)"
        }
        # …and when the named DB IS the current one, the trace stays byte-
        # identical to a pre-§D1 trace: no keys, no `%`, no alias.
        if {[dict get $hit cur]} { set hit {} }
      } else {
        set err [wviewer::validate_rpn $rpn $varlist]
        if {$err ne {}} {
          set hit [wviewer::resolve_signal_db $token $rpn]
          if {$hit eq {}} { return $err }
        }
      }
      if {$hit ne {}} {
        # a FOREIGN DB. It can only be carried into `node=` if its registry path
        # and type survive the `%` grammar (db_path_safe: the two rounds of
        # `subst`, the "\n " field split, the `%` separator, the `"` quote).
        # Refusing LOUDLY here is the honest move: emitting a suffix the engine
        # cannot switch on would silently draw nothing.
        if {![wviewer::db_path_safe [dict get $hit path]] ||
            ![wviewer::db_path_safe [dict get $hit type]]} {
          return "'$rpn' is in [dict get $hit label], but that database's path\
cannot be carried in a graph node= token (it contains whitespace or one of % \" \\ \$ \[ \] { })"
        }
        set trdb $hit
      }
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
  set trd [dict create expr $rpn name $name vec $vec color $col]
  # §D1: carry the DB the signal was picked from. The keys are ABSENT for an
  # ordinary current-DB trace, so every existing model dict, state file and
  # emitted node= string is byte-identical to before.
  if {$trdb ne {}} {
    dict set trd rawfile  [dict get $trdb path]
    dict set trd sim_type [dict get $trdb type]
  }
  lappend trs $trd
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

# --- item 7: the per-window plot DESTINATION ----------------------------------
# THE accessor. Everything that decides where a plot gesture lands must call
# this — the Add Trace dialog, plot_signals, and (item 9) the browser toolbar's
# three plot gestures. Nothing may re-implement the policy, exactly as nothing
# may re-implement sig_match.
#
# ⚠ Unlike plot_mode, this DEFAULTS rather than returning {} for an unset token:
# `mode` is seeded at `open` time and its {} truthfully means "no window", but
# there is no open-time seed for the destination, so the default lives here.
# `append` is the answer for an unknown token too, and that is deliberate: a
# caller that asked for the destination of a window that is not there must get
# the harmless policy, not a policy that destroys traces.
proc wviewer::plot_dest {{token {}}} {
  variable dest
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists dest($token)]} { return append }
  return $dest($token)
}

# Set the destination. `req` is a LABEL or a CODE (wviewer::dest_norm). Returns
# the RESOLVED code, or {} plus a CIW error when the token resolves to no open
# viewer — the set_plot_mode shape, deliberately.
#
# Logs `wviewer::set_plot_dest <code> <token>` ON AN ACTUAL CHANGE ONLY, and
# always the resolved CODE (never the label) with an explicit token: the same
# rule set_plot_mode and set_target_strip follow, so a replay does not fill with
# redundant lines and does not depend on which window is active at replay time.
proc wviewer::set_plot_dest {req {token {}}} {
  variable dest
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to set the plot destination on" error
    }
    return {}
  }
  set new [wviewer::dest_norm $req]
  set cur [wviewer::plot_dest $token]
  if {$new eq $cur} { return $cur }
  set dest($token) $new
  wviewer::log_action [list wviewer::set_plot_dest $new $token]
  return $new
}

# The WINDOW-level half of the destination policy: everything that must happen
# BEFORE plan_plot can speak. Today that is exactly `newtab`; the other three
# destinations have nothing to prepare and succeed trivially.
#
# Returns 1 on success (INCLUDING "nothing to do"), 0 when the tab could not be
# made — in which case the caller must report and abort rather than plot into
# the wrong tab.
#
# ⚠ MEASURED: new_tab calls tab_drop_transients, which DESTROYS $top.wvadd. Any
# caller that still needs something out of the Add Trace dialog must have read
# it BEFORE calling this, and must guard every widget access afterwards. That is
# not theoretical — it is why add_trace_ok snapshots its picks by name first and
# routes its errors through wviewer::echo when the label is gone.
proc wviewer::dest_prepare {token dest} {
  if {[wviewer::dest_norm $dest] ne {newtab}} { return 1 }
  if {[wviewer::new_tab $token] eq {}} { return 0 }
  return 1
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

# --- spec §D1 / DEFECT 2: the per-signal DATABASE hand-off -------------------
#
# ⚠⚠ WHY THIS IS AN ARMED HAND-OFF AND NOT `plot_signals`' FIFTH ARGUMENT, which
# is what it would obviously be. `wviewer::plot_signals`' four-parameter
# signature is PINNED BY A LITERAL STRING MATCH — tests/headless/
# test_wave_sigbrowser.tcl BM05 asserts
# `proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}` appears in
# this file verbatim, and BM05 also asserts browser_plot_ids calls it as
# `wviewer::plot_signals $token $names {} $destover` exactly once. Worse, BOTH
# plot_signals SPIES in that suite are declared with exactly four parameters, so
# a five-argument call would be "too many arguments", swallowed by
# browser_plot_ids' own catch, and every BT gesture check there would read as
# "the gesture did nothing" — the very trap that file's own ⚠ records item 10
# falling into when `destover` was added. A parallel list is the RIGHT shape
# (it is exactly `colors`'), and if that pin is ever relaxed this should become
# `{dbs {}}` and these two procs should go.
#
# THE ONE-SHOT DISCIPLINE, which is what keeps a hidden channel honest:
#  * `plot_dbs_take` CONSUMES — it unsets — so a stale arm can never be read
#    twice, and `plot_signals` takes FIRST THING, before any early return;
#  * `browser_plot_ids` (the TREE's plot route) takes-and-discards after its
#    call as well, so an arm made while a TEST has renamed plot_signals away is
#    still cleared;
#  * `browser_sea_plot_idx` (the LOWER PANE's plot route, §F item F6) does the
#    same, and for the same reason — it is the SECOND armer and it obeys the
#    identical arm/call/take shape;
#  * `wviewer::forget` drops it with the window.
# EXACTLY TWO CALLERS ARM IT and they are the browser's two plot routes:
# `browser_plot_ids` from the tree and `browser_sea_plot_idx` from the lower
# pane. Every other plot_signals caller (Direct Plot, the Add Trace… dialog) has
# only names, and {} is exactly right there. ⚠ The lower pane was NOT an armer
# before §F item F6 — until then it could only ever hold the CURRENT database's
# names, so a bare name resolved right by construction; it can hold a foreign
# database's names now, so it must say which.
proc wviewer::plot_dbs_arm {token dbs} {
  variable plotdbs
  set plotdbs($token) $dbs
  return {}
}
proc wviewer::plot_dbs_take {token} {
  variable plotdbs
  if {![info exists plotdbs($token)]} { return {} }
  set v $plotdbs($token)
  unset plotdbs($token)
  return $v
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
#
# `destover` (item 10) is a ONE-SHOT destination override — the browser's
# `Plot to →` cascade, which must land this ONE batch somewhere else without
# changing where the NEXT gesture lands. Ruling 24 is intact and this is why it
# is an ARGUMENT and not a save/restore around `set_plot_dest`: `plot_dest`
# remains THE accessor for the window's policy, the override never writes
# `dest($token)`, and a save/restore would log two spurious replay lines and
# leave the window on the wrong policy if anything below threw. `{}` = use the
# window's policy, which is every pre-item-10 caller.
#
# The per-signal DATABASE (spec §D1 / DEFECT 2) arrives out of band, through
# `wviewer::plot_dbs_arm` / `plot_dbs_take` — see their header for why it is not
# a fifth parameter here. It is taken FIRST THING below, so a gesture that arms
# and then fails before the trace loop cannot leak its list into the next one.
proc wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
  set dbs [wviewer::plot_dbs_take $token]
  variable windows
  if {![dict exists $windows $token]} {
    return [list [list {} "unknown viewer window"]]
  }
  # issue 0194: the ONE capture for the whole batch, before any strip is
  # created. add_trace's own capture cannot serve here — it runs after the
  # strips were added, where the 1:1 rect/model guard refuses it.
  wviewer::capture_live_view_state $token
  # item 7: THE window destination governs this seam, and this seam ONLY — it is
  # the one route every plot gesture (Direct Plot, and item 9's three browser
  # gestures) shares, so the policy is implemented once here and nowhere else.
  # The WINDOW half runs first and may replace the whole layout (New Tab), hence
  # the re-read below.
  # ⚠ ONE resolution, BEFORE dest_prepare, so the override governs the window
  # half (New Tab) and plan_plot alike. A second read anywhere below would be a
  # place the two could disagree.
  set dest [expr {$destover eq {} ? [wviewer::plot_dest $token]
                                  : [wviewer::dest_norm $destover]}]
  if {![wviewer::dest_prepare $token $dest]} {
    return [list [list {} "cannot open a new tab for this plot"]]
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set mode [wviewer::plot_mode $token]
  set auto [wviewer::auto_graph_index $token]
  set plan [wviewer::plan_plot $mode [llength $gs] \
                               [wviewer::target_index $token] [llength $exprs] \
                               $auto [wviewer::empty_graph_indices $gs $auto] \
                               $dest]
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
  # item 7 `replace`: empty the landing strips that ALREADY EXISTED, AFTER the
  # new strips were created (so the multi arm's post-insert indices are the live
  # ones) and BEFORE anything is added. The key is present only under `replace`,
  # and it never names a strip this plan just made OR reused because it was
  # already empty, so this loop never makes a no-op clear_graph_traces call —
  # see plan_replace_clear. Under multi it is therefore always empty (declared
  # in plan_plot's ⚠⚠: Replace is a single-mode policy).
  foreach ci [wviewer::dget $plan clear {}] {
    wviewer::clear_graph_traces $token $ci
  }
  set errs {}
  # `dbs` is padded to `exprs`' length rather than relying on `foreach`'s own
  # short-list padding: an empty `dbs` must give EVERY signal `{}` (resolve by
  # name), and a caller that supplied a short list must not silently hand the
  # tail somebody else's database.
  set dblist {}
  for {set i 0} {$i < [llength $exprs]} {incr i} {
    lappend dblist [expr {$i < [llength $dbs] ? [lindex $dbs $i] : {}}]
  }
  foreach ex $exprs gi [dict get $plan targets] col $colors db $dblist {
    set err [wviewer::add_trace $token $gi $ex {} $col $db]
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

# --- the Signal Browser sidebar (signal-browser PLAN item 8) -----------------
#
# SETTLED DECISION 1: the browser is a LEFT SIDEBAR inside the viewer toplevel,
# not a separate toplevel and not a floating assistant. xschem has no
# dockable-assistant framework and building one buys this batch nothing.
#
# Item 8 ships the SHELL ONLY: the frame, a placeholder label, the pack/unpack
# pair, the menu twin and the key. Items 9-15 fill it, and per settled decision
# 13 they must derive its content from `xschem raw list` / `xschem raw`, NEVER
# from the rect model (issue 0186 is still open and blanks the document under a
# CIW `xschem reload`).

# --- item 9: the PURE half — what the tree SHOULD contain --------------------
# plan_plot/plot_signals' split, reused: the row list is computed by a proc that
# touches no widget, so grouping, de-duplication and the search/filter AND are
# all testable in `--nogui`, where there is no Tk at all. Only the insertion
# needs a display.

# Is this signal class a DEVICE class? PURE.
#
# It exists so `devnode`/`devmeas` is written down exactly ONCE. Two call sites
# that each spell out the set drift the first time a class is added, and the
# drift is invisible: the tree and the signal list simply start disagreeing
# about what a device is, which reads as a display bug rather than a logic one.
#
# ⚠ `srcbranch` is deliberately NOT a device class. A voltage source you placed
# inside a subcircuit to measure a current is a thing you DREW; a MOSFET's
# `#body` node is a thing the model generated. They get separate checkboxes
# (spec R11) because they answer separate questions. Fold `srcbranch` in here
# and the two boxes collapse into one. Pinned by TP03.
#
# ⚠⚠ `digital` IS NOT A DEVICE CLASS EITHER, AND THAT IS RULING F4's SECOND HALF,
# not an omission. Ruling B (issue 0217) says device internals are hidden BY
# DEFAULT; a digital signal that answered 1 here would therefore be hidden by
# default, i.e. loading a VCD would show the user an empty tree. RULING F4 is
# what makes `digital` a class the two boxes do not govern at all -- the boxes
# partition an ANALOG raw, and a VCD has no devices for them to talk about.
# Pinned by FD30/FD31: adding `digital` to this list reds them.
proc wviewer::sig_is_device {class} {
  return [expr {$class eq {devnode} || $class eq {devmeas}}]
}

# Narrow an entry list by CLASS, for the two independent checkboxes (spec R11).
# PURE. `devint` = show device internals (default 0), `srccur` = show internal
# source branch currents (default 1).
#
# MEASURED on tb_bandgap's 424 signals: devint 0 leaves 190; devint 0 + srccur 0
# leaves 140; design nets alone would be 139 (the 140th is the sweep variable,
# which M8 deliberately does not special-case). tb_charge_pump: 1191 -> 146 ->
# 120, nets-only 119.
#
# ⚠ THE tb_charge_pump TRIPLE WAS WRONG BY EXACTLY 9 IN EVERY TERM (it read
# 137 / 111 / 110) and travelled that way through the spec too. RE-MEASURED at
# TWO-PANE item 19 on the committed fixture with this proc: class histogram
# net 120, srcbranch 26, devmeas 283, devnode 762, summing to 1191. The
# tb_bandgap triple above re-measures correct and is unchanged.
#
# ⚠ THE MUCH-QUOTED "424 -> 139" IS WRONG as a description of hiding device
# internals. It needs source-branch currents AND the sweep variable hidden too.
# Hiding internals alone gives 190. The figure travelled through three planning
# docs unchallenged; it is corrected here and in the spec.
#
# ⚠ RAW-FILE ORDER IS PRESERVED (limit D7, pinned by TP09). Every downstream
# gesture resolves a row INDEX back into this list, so a filter built on a dict
# or ending in `lsort -unique` would keep every count check green while silently
# reordering the user's plots.
proc wviewer::browser_class_filter {entries devint srccur} {
  if {$devint && $srccur} { return $entries }
  set out {}
  foreach e $entries {
    set c [wviewer::dget $e class net]
    if {!$devint && [wviewer::sig_is_device $c]} { continue }
    if {!$srccur && $c eq {srcbranch}} { continue }
    lappend out $e
  }
  return $out
}

# The dotted paths of hierarchy nodes that hold NOTHING BUT device signals, and
# which the tree therefore hides while `Show device internals` is off. PURE.
# Spec doc/claude/specs/waveform_signal_browser_two_pane.md §3.3.
#
# ⚠⚠ THE `x` PREFIX IS NOT A DISCRIMINATOR AND MUST NEVER BE USED AS ONE. The
# obvious implementation — "keep only segments that look like subcircuit
# instances" — is a NO-OP. MEASURED over the 22-raw corpus: ALL 85 distinct
# post-declass path segments begin with `x`, because sky130 wraps its MOSFETs in
# pcell SUBCIRCUITS. `xm1` is grammatically a real X-instance and lexically
# indistinguishable from `x2`. The class tag captured at declass time
# (signal_entry's ⚠) is the only evidence that exists.
#
# ⚠ THE RULE IS `EVERY SIGNAL AT OR UNDER IT`, NOT `ANY`, and that is not a
# nicety. MEASURED: sky130 pcell-wraps MOSFETs but NOT capacitors, and
# resistor/bipolar parasitic sub-devices sit at a level SHARED with real nets —
# 32 such signals across 5 of the 22 designs. `x1.xr1.x0` carries the design
# nets `t1`/`t2` AND `@r...[i]` measurements at the same level, so an `any`
# rule deletes the node and takes two real nets with it. TP11 is that oracle,
# and TP12's positive control (drop the net, the node MUST become a device
# node) is what stops TP11 passing on an implementation that hides nothing.
#
# The accumulator starts each node at "all device" and is knocked down to 0 by
# the first non-device signal at or under it, which is the `every` quantifier
# expressed in one pass rather than a subtree walk per node.
proc wviewer::browser_device_paths {entries} {
  array set all {}
  foreach e $entries {
    set p [wviewer::dget $e path {}]
    if {$p eq {}} { continue }
    set dev [wviewer::sig_is_device [wviewer::dget $e class net]]
    set pref {}
    foreach seg [split $p .] {
      set pref [expr {$pref eq {} ? $seg : "$pref.$seg"}]
      if {![info exists all($pref)]} { set all($pref) 1 }
      if {!$dev} { set all($pref) 0 }
    }
  }
  set out {}
  foreach k [array names all] { if {$all($k)} { lappend out $k } }
  return $out
}

# --- item 4: the NODE-ONLY projection and the design-root label (R1, R2) ------
#
# The UPPER pane's row list: `browser_rows`' output with every leaf dropped.
# PURE, and a FILTER rather than a rebuild — which is what preserves
# parents-before-children for free, so browser_populate still inserts in one
# pass. A projection re-collected from a dict does not preserve it and ttk then
# throws on the first orphan.
#
# ⚠ THE FULL ROW LIST IS NOT REPLACED BY THIS. `browserrows($token)` keeps the
# LEAVES — browser_leaf_names, browser_plot_ids, browser_menu_ids,
# browser_target_path and browser_descend_to all read it, and R6 keeps the tree's
# plot gesture recursive. Feeding this projection into `browserrows` instead is
# the single most likely wrong edit in the batch: nothing would be plottable and
# only one check would say so.
#
# ⚠ R1's DEVICE-NODE PRUNE IS NOT HERE, AND IS NOT A THIRD PROC. It falls out
# structurally: browser_refresh runs `browser_class_filter` BEFORE
# `browser_rows`, so a node all of whose signals are device-classed has no
# surviving entry and is never minted. That satisfies R1's `EVERY signal at or
# under it` quantifier exactly — `x1.xr1.x0` survives because its real nets do —
# and it is the same number `browser_device_paths` answers directly: MEASURED
# 128 -> 44 (84 hidden) for tb_bandgap, 316 -> 13 (303) for tb_charge_pump.
proc wviewer::browser_tree_rows {rows} {
  set out {}
  foreach r $rows {
    if {[wviewer::dget $r kind {}] ne {group}} { continue }
    lappend out $r
  }
  return $out
}

# The design name for the root row (R2). PURE.
#
# ⚠ IT MAY NEVER ANSWER {}, and that is load-bearing rather than defensive:
# `browser_rows` emits the root only when the label is non-empty, so an empty
# label silently deletes the root row — and R4's "there is always exactly one
# node selected" then has nothing to select, on exactly the degenerate paths
# (no raw loaded, a dotfile, a trailing slash) where it is least likely to be
# noticed. `design` is the floor.
#
# `_ase` is stripped because ASE writes `<cell>_ase.raw` beside the schematic;
# the user drew `tb_bandgap`, not `tb_bandgap_ase`. Only the SUFFIX goes.
proc wviewer::browser_root_label {path} {
  if {$path eq {}} { return design }
  set b [file rootname [file tail $path]]
  regsub {_ase$} $b {} b
  if {$b eq {}} { return design }
  return $b
}

# The full raw names owned by EXACTLY ONE hierarchy level — the lower pane's
# selector (spec R3). PURE. Raw-file order (limit D7).
#
# ⚠⚠ THIS IS A SECOND PROC, NOT A CHANGE TO `browser_leaf_names`, and that is
# ruling R6 rather than duplication. `browser_leaf_names` is RECURSIVE BY
# CONTRACT — its own header says "a group answers with every leaf beneath it,
# however deep" — and the driver kept it that way deliberately: plotting
# everything under a block is how you find what is coupling into a signal you
# can see a kink on. MEASURED on tb_bandgap's `x1`: own-level 43, recursive 406.
# Two different questions; changing the old proc to answer the new one would
# red BT13/BM12/BT29/BT32 and delete the gesture the driver asked to preserve.
#
# ⚠ CASE-INSENSITIVE, and not as a courtesy: ngspice lowercases, so the raw says
# `x1.x2` while the schematic says `X1`. Spec §10.3-10.4 — the final verify must
# be `-nocase` too, or a correct walk of `x1.x2` lands on `x1.X2` and is
# rejected by its own verify.
#
# A path with no signals of its own answers `{}`. That is an ANSWER, not an
# error: MEASURED, 18 of tb_bandgap's 128 nodes and 25 of tb_charge_pump's 316
# are pure ancestors that exist only because a descendant does.
#
# ⚠⚠ AND CASE-**SENSITIVE** FOR A `digital` ENTRY, WHICH IS NOT AN EXCEPTION TO
# THE RULE ABOVE BUT THE SAME RULE READ CORRECTLY. `-nocase` is a fact about
# NGSPICE (it lowercases, so the raw and the schematic disagree by case and only
# by case); Verilog is case-SENSITIVE and `vcd_read.c` stores names verbatim, so
# `top.mod` and `top.MOD` are two LEGAL SIBLING SCOPES with different contents.
# Folding them here answers with the other scope's signals — MEASURED on the two
# names `top.mod.a` and `top.MOD.b`, this proc answered BOTH for BOTH paths while
# `browser_rows` (correctly) built two distinct groups, so selecting either scope
# drew the other one's wires under a caption counting them. `browser_names_under`
# already rules this exact point the same way and for the same reason; RULING F4
# is what put digital names in front of this proc, so the reasoning has to come
# with them. The test is the ENTRY's OWN class, not a database argument, because
# an entry list is the only thing this proc is ever given.
proc wviewer::browser_level_names {entries path} {
  set out {}
  foreach e $entries {
    set p [wviewer::dget $e path {}]
    if {[wviewer::dget $e class {}] eq {digital}} {
      if {$p ne $path} { continue }
    } elseif {![string equal -nocase $p $path]} {
      continue
    }
    lappend out [wviewer::dget $e name {}]
  }
  return $out
}

# The FULL raw name behind a row — for the tooltip, for Copy names, and for
# every gesture. The label is a DISPLAY, never an identity.
proc wviewer::browser_label_full {e} { return [wviewer::dget $e name {}] }

# ONE entry -> its lower-pane label, Cadence convention (spec R8). PURE.
#
# Voltages render bare (`net5`); currents render `<instance>:<param>`
# (`xm1:id`, `v1:i`, `c1:i`, `xm1:#body`).
#
# ⚠ THE BARE TEST IS `class net AND type ne i`, NOT type alone. A device
# internal node has type `v` and must NOT render bare — `v(m.x1.xm1.mod#body)`
# is `xm1:#body`, not `mod#body`.
#
# ⚠⚠ THE INSTANCE HALF IS *NOT* SIMPLY THE LAST PATH SEGMENT. The spec said so
# in its first draft and its own worked examples contradicted it:
# `i(@c.x1.c1[i])` has last path segment `x1`, giving `x1:i`, not the `c1:i` the
# table demands. Both candidate rules were run over all 2656 corpus names:
#
#   last path segment  ->  reproduces 6 of 7 spec rows, 29 label COLLISIONS
#   the hybrid below   ->  reproduces 7 of 7,            0 collisions
#
# THE RULE: the instance half is the LEAF'S BASE, unless that base is
# MODEL-SHAPED — it contains `_` — in which case it is the LAST PATH SEGMENT.
# The asymmetry is not arbitrary: sky130 names the device INSIDE a pcell wrapper
# after its model (`msky130_fd_pr__nfet_01v8`), so there the wrapper `xm1` is the
# instance the user drew; a discrete `c1`/`r1`/`q1` has no wrapper and IS its own
# instance. One rule, two shapes, because the corpus genuinely has two shapes.
#
# ⚠ One leading `@` is stripped: 25 corpus names are untagged single-segment
# `@`-forms (11 in cmos_ac_sweep), which would otherwise read `@ibias:current`.
#
# ⚠ Only NINE distinct params exist in the whole corpus ([id] 356, [i] 114,
# [current] 11, [vth] 3, [is]/[ie]/[ic]/[ib] 2 each, [vbe] 2, [gm] 1), so the
# param passes through VERBATIM. No translation table is needed or wanted.
#
# ⚠ TWO SIGNALS CAN RENDER TO THE SAME LABEL. Declared limit, not a defect: the
# label is a display, every gesture resolves through the row INDEX into the full
# raw name, and the status line counts names rather than labels so a collision
# stays visible.
#
# ⚠⚠ RULING F4: A `digital` ENTRY ALWAYS RENDERS BARE, AHEAD OF EVERY OTHER RULE.
# The whole `<instance>:<param>` half below is about SPICE currents, and a VCD has
# none: its `type` is `other` for every name (there is no `v(`/`i(` wrapper to
# read), so the `class eq net` test alone would drop a digital name into the
# current formatter. MEASURED on `m.sub.count[3]`: `param` would capture the
# BIT INDEX out of the brackets and the pane would draw `count:3` for bit 3 of a
# bus -- a label that reads like a current on a signal that is not one. A bare
# `sig` becomes `sig:i` the same way. FD32/FD33 are those two, as values.
#
# ⚠ THE EXEMPLAR IS `m.sub.count[3]` AND NOT A `TOP.`-ROOTED ONE, which is a
# correction and not a typo: `TOP.counter.count[3]` classes `net` (no one-letter
# head for `sig_declass` to take), takes the `class eq net` early return and
# renders `count[3]` on BOTH readings, so it demonstrates nothing. The names this
# arm actually changes are the ones a one-letter scope makes device-shaped —
# which is the same family RULING F4 exists for. The spec's table and FD33 both
# use `m.sub.count[3]`; this comment used to name the other one and call it
# measured.
proc wviewer::browser_label {e} {
  set leaf  [wviewer::dget $e leaf {}]
  set class [wviewer::dget $e class net]
  set type  [wviewer::dget $e type other]
  if {$class eq {digital}} { return $leaf }
  if {$class eq {net} && $type ne {i}} { return $leaf }
  set base $leaf
  set param {}
  if {[regexp {^(.*?)\[([^][]*)\]$} $leaf -> b p]} {
    set base $b ; set param $p
  } elseif {[regexp {^([^#]*)(#.*)$} $leaf -> b p]} {
    set base $b ; set param $p
  }
  if {$param eq {}} { set param i }
  set inst $base
  if {[string first _ $base] >= 0} {
    set segs [split [wviewer::dget $e path {}] .]
    set last [lindex $segs end]
    if {$last ne {}} { set inst $last }
  }
  regsub {^@} $inst {} inst
  return "${inst}:${param}"
}

# --- TWO-PANE ITEM 20: THE FILTER SUBJECT ------------------------------------
#
# ONE raw name -> the label the lower pane renders for it. PURE, and the ONLY
# spelling of "what the user is looking at" the matcher is ever given: it is
# passed to `sig_match -key` by `browser_match` and by `browser_refresh`'s
# All-DBs loop, and by nothing else.
#
# ⚠⚠ THE BARS NOW MATCH THIS AND STILL RETURN THE RAW NAME. The pane draws
# `net1` while the name is `v(x1.net1)`, and ruling 3 anchors wildcards to the
# WHOLE subject — so before this, `net*` matched 0 of tb_bandgap's 43 signals at
# x1 and only the accidental `*net*` substring form ever worked. MEASURED at
# that node: `net*` 0 raw / 26 label, `net1*` 0 / 11, `*1` 0 / 4.
#
# ⚠ IT DOES NOT MAKE THE LABEL AN IDENTITY. A filter selects WHAT TO SHOW and
# resolves nothing: every gesture still goes through the row index into the full
# raw name (browser_sea_name), and the status line still counts NAMES. Spec R8's
# "the label is a display, never an identity" is restated by item 20, not
# weakened by it.
#
# ⚠⚠ RULING F4 SPLITS THIS IN TWO, AND THE ORDER OF THE ARGUMENTS IS THE REASON.
# `sig_match` invokes the key as `eval $key [list $name]`, i.e. as a COMMAND
# PREFIX, so the only way to tell it which database a name came from is to CURRY
# the database in front: `[list wviewer::browser_label_of_db vcd]`. Both production
# key sites (browser_match, and browser_refresh's All-DBs loop) pass the curried
# form; `browser_label_of` stays exactly as it shipped, one argument and analog,
# for every caller that has no database in hand -- which is every direct unit test
# of the matcher (SM29, SM30, BD57's negative control). Making the signature take
# the type and rewriting those five call sites would have moved five checks for a
# fact none of them is about.
proc wviewer::browser_label_of_db {dbtype name} {
  return [wviewer::browser_label [wviewer::signal_entry $name $dbtype]]
}
proc wviewer::browser_label_of {name} {
  return [wviewer::browser_label_of_db {} $name]
}

# --- the "sea of names" flow: column-major layout arithmetic (M2, R3) --------
#
# PURE, and deliberately so. The flow is the one part of a canvas megawidget
# that can be tested without a display, and keeping it here is what stops the
# X-arm checks having to prove arithmetic and geometry at the same time. Only
# the DRAWING needs Tk.
#
# The algorithm is Tk 8.6's own `::tk::IconList::Arrange`
# (/usr/share/tcltk/tk8.6/iconlist.tcl:301-376) reimplemented rather than
# reused: that class is declared private and experimental (megawidget.tcl:1-15),
# requires an image per batch, exposes no per-item colour API, and binds no
# <Button-3>.

# n items at `rowh` px in a pane `paneh` px tall -> {itemsPerColumn ncolumns}.
#
# ⚠ THE `< 1 -> 1` FLOOR IS LOAD-BEARING, not defensive. IconList carries the
# same one (iconlist.tcl:370-373) because every subsequent placement divides by
# this number: a pane shorter than one row would otherwise divide by zero.
proc wviewer::browser_flow_layout {n rowh paneh} {
  if {$rowh <= 0} { set rowh 1 }
  set per [expr {$paneh / $rowh}]
  if {$per < 1} { set per 1 }
  return [list $per [expr {($n + $per - 1) / $per}]]
}

# item index -> {x y}, COLUMN-MAJOR: fill a column top to bottom, then start the
# next one to the RIGHT. Row-major here would be a one-character change that
# looks right in a screenshot and is wrong in every other way.
proc wviewer::browser_flow_cell {idx per colw rowh} {
  if {$per < 1} { set per 1 }
  return [list [expr {($idx / $per) * $colw}] [expr {($idx % $per) * $rowh}]]
}

# canvas coords -> item index, or -1 for a MISS.
#
# ⚠⚠ ARITHMETIC, NOT `find closest`, AND THE DIFFERENCE IS THE MISS. IconList
# hit-tests with `find closest`, which is O(n) in canvas items and — worse —
# ALWAYS RETURNS SOMETHING: a click in the gutter past the last column silently
# selects a neighbour. The flow is a regular grid, so `col*per + row` is O(1)
# and can honestly answer "nothing here". Three distinct ways to be outside, all
# of which `find closest` gets wrong in the same silent way: below the last row
# of a full column, right of the last column, and past the last item in a
# PARTIAL column.
proc wviewer::browser_flow_hit {x y per colw rowh n} {
  if {$per < 1} { set per 1 }
  if {$colw <= 0 || $rowh <= 0} { return -1 }
  if {$x < 0 || $y < 0} { return -1 }
  set col [expr {int($x) / $colw}]
  set row [expr {int($y) / $rowh}]
  if {$row >= $per} { return -1 }
  set idx [expr {$col * $per + $row}]
  if {$idx < 0 || $idx >= $n} { return -1 }
  return $idx
}

# the canvas -scrollregion for a flowed pane.
#
# ⚠⚠ THE HEIGHT IS CLAMPED TO THE PANE, AND THAT CLAMP IS THE ENTIRE MECHANISM
# BEHIND R3's "HORIZONTAL SCROLLBAR ONLY". Let the height be the content height
# and Tk hands the canvas a vertical range to scroll, which is the one thing R3
# forbids — the pane would then have a hidden vertical axis with no scrollbar to
# reach it. IconList clamps it the same way (iconlist.tcl:359-368).
proc wviewer::browser_flow_scrollregion {cols colw paneh} {
  return [list 0 0 [expr {$cols * $colw}] $paneh]
}

# `entries` are item-2 dicts {name type leaf path class}. Returns an ORDERED
# list of row dicts {id .. parent .. text .. kind group|leaf .. name ..}, parents
# always BEFORE their children (which is what lets browser_populate insert them
# in order without a second pass).
#
# ⚠ THE `g:` / `s:` ID PREFIXES ARE LOAD-BEARING, not decoration. A raw signal
# literally named `x1.x2` and the GROUP `x1.x2` minted by `v(x1.x2.net5)` would
# otherwise claim the same treeview id — and a duplicate id THROWS
# (`Item ... already exists`, measured on Tk 8.6.14). A throw here lands on the
# searchbar's <KeyRelease> pump, i.e. bgerror, i.e. a modal dialog under X.
# The `#<n>` de-dup below is mandatory for the same reason: two identical names
# in one raw file are legal.
#
# Grouping is per DOT SEGMENT of the entry's `path` (ruling 14: `path`/`leaf`
# split the UNWRAPPED name, so `v(x1.x2.net5)` -> path `x1.x2`, leaf `net5`,
# and the tree reads `x1 > x2 > net5` rather than growing a node called `v(x1`).
# Groups are minted lazily, in first-appearance order.
#
# FLAT when NO entry has a path (the PLAN's clause). An entry with an empty path
# stays at top level even when other entries are grouped.
#
# --- item 2: the two OPTIONAL arguments (two-pane spec R2, M6) ----------------
#
# `root` — when non-empty, ONE extra group row is emitted FIRST, id `g:` (the
# empty prefix), text `$root`, and everything that would have been top level
# hangs off it instead. That is spec R2's "exactly one root node, named for the
# design, selected when the browser opens", and `g:` is the id BECAUSE the
# SHIPPED two-character strip in browser_target_path decodes it to the empty
# path — the legitimate sim-root ascend — with zero change to that proc. (`r:`
# and `root:` were both rejected; `root:` decodes to `ot:`.)
#
# ⚠ THE RE-PARENT MUST REACH THE EMPTY-PATH LEAVES TOO, not only the groups.
# `v(vbg)` never enters the segment loop, so seeding `parent` — rather than
# patching the group rows afterwards — is what makes R2's "top-level signals are
# the root's own-level signals" true, and what makes R6's recursive plot on the
# root reach every name. TP28/TP29 are the two halves.
#
# `anypath` — overrides the flat-mode gate; a non-integer (the `{}` default)
# means "compute it here", which is what keeps every shipped caller unchanged.
#
# ⚠⚠ MEASURED, AND NARROWER THAN M6 CLAIMS. The flat/hierarchical choice is
# ALSO gated per entry on `$path ne {}`, so forcing the gate to 1 on a set whose
# entries all have empty paths changes NOTHING — there are no segments to mint.
# The override is observable in exactly ONE direction: forcing 0 flattens a
# PATHED set. M6's stated failure mode ("designs flip to flat mode if the gate
# is computed after the class filter") therefore cannot arise: when the filter
# leaves no pathed entry the rows are identical either way, and when it leaves
# one the auto-gate already answers 1. TP32 pins that as a value rather than
# leaving it an assumption. The argument stays because browser_refresh passes
# the PRE-filter gate deliberately (M6's source-order claim), not because the
# post-filter value would differ.
proc wviewer::browser_rows {entries {root {}} {anypath {}}} {
  if {![string is integer -strict $anypath]} {
    set anypath 0
    foreach e $entries {
      if {[wviewer::dget $e path {}] ne {}} { set anypath 1 ; break }
    }
  }
  set rows {}
  array set seen {}
  array set grp {}
  set rootid {}
  if {$root ne {}} {
    set rootid {g:}
    set seen($rootid) 1
    set grp($rootid) 1
    lappend rows [dict create id $rootid parent {} text $root kind group name {}]
  }
  foreach e $entries {
    set name [wviewer::dget $e name {}]
    set leaf [wviewer::dget $e leaf $name]
    set path [wviewer::dget $e path {}]
    set parent $rootid
    if {$anypath && $path ne {}} {
      set pfx {}
      foreach seg [split $path .] {
        set pfx [expr {$pfx eq {} ? $seg : "$pfx.$seg"}]
        set gid "g:$pfx"
        if {![info exists grp($gid)]} {
          set grp($gid) 1
          set seen($gid) 1
          lappend rows [dict create id $gid parent $parent text $seg \
                          kind group name {}]
        }
        set parent $gid
      }
    } else {
      # ungrouped: the row text is the whole name, not the last dot-segment —
      # a flat list that showed only `net5` for `v(x1.x2.net5)` would be lying
      set leaf $name
    }
    set id "s:$name"
    if {[info exists seen($id)]} {
      set n 2
      set cand "s:$name#$n"
      while {[info exists seen($cand)]} { incr n ; set cand "s:$name#$n" }
      set id $cand
    }
    set seen($id) 1
    lappend rows [dict create id $id parent $parent text $leaf \
                    kind leaf name $name]
  }
  return $rows
}

# PURE (item 14). Re-key a row list so it can be nested under a DB header:
# every `id` gains `$prefix`, a row whose `parent` is {} adopts `$parent`, and a
# row that already had a parent keeps it — PREFIXED, so no child is left
# pointing at an id that is no longer in the list. Without the second half a
# grouped foreign inventory (`v(x1.out)`) would insert under a `g:x1` that only
# exists unprefixed in the CURRENT DB's rows, and ttk would either steal the
# node or throw.
proc wviewer::browser_rows_reparent {rows prefix parent} {
  set out {}
  foreach r $rows {
    set par [wviewer::dget $r parent {}]
    dict set r id "$prefix[wviewer::dget $r id {}]"
    dict set r parent [expr {$par eq {} ? $parent : "$prefix$par"}]
    lappend out $r
  }
  return $out
}

# PURE (item 14). Several inventories -> ONE row list. `groups` is a list of
#
#     {id label entries ?root? ?prefix?}
#
# a group whose LABEL is empty is emitted FLAT and UNPREFIXED — that is the
# CURRENT DB with All-DBs off, and it goes first.
#
# ⚠⚠ THE LAST TWO ELEMENTS ARE TWO-PANE ITEM 15 (spec R7 / §4.3) AND BOTH ARE
# OPTIONAL, so every 3-element call is byte-identical to what item 14 shipped
# (BD19-BD25c, TP33, TP40, TP41).
#  * `root` — THIS group's design-root label. Without it there is only the
#    shared `$root` below, threaded into every group, so every DB's root would
#    render the CURRENT design's name under a FOREIGN DB's header — the tree
#    would name the wrong run. Defaults to `$root`, which is what a 3-element
#    call gets. BD62b.
#  * `prefix` — supplied ONLY by the current DB, and only as `{}`. Absent, it
#    defaults to `<id>|`, which is item 14's behaviour. The current DB keeps
#    UNPREFIXED ids even when R7 puts it under a header, because the prefix is
#    the DB's REGISTRY INDEX and that is not a property of the design: it moves
#    when raws are loaded in another order or one is closed, and every persisted
#    tree id (`browser_tree_state`) would then name a row that no longer exists.
#    MEASURED in test_wave_sigbrowser_i1315.tcl BP47b, where the index really
#    does move 1 -> 0 across a snapshot/restore. §4.3's closing sentence rules
#    the same way ("the current DB is always group 0 ... unprefixed"); only its
#    "unlabelled" half is superseded by R7.
#  * `[llength $g] >= 5` rather than `$gpfx ne {}`, because `{}` IS the value the
#    current DB passes — "absent" and "deliberately empty" must not collapse.
#
# ⚠ TWO PROPERTIES THE REST OF THE BROWSER DEPENDS ON, both deliberate:
#  * the header row's kind is `group`, NOT a new kind. browser_plot_at's
#    `!$groups` guard, browser_leaf_names' parent walk and browser_menu_ids then
#    all work UNCHANGED — a double-click on a DB header expands it, Plot/MMB
#    plots its leaves, and item 14 adds no new row vocabulary;
#  * the current DB's rows are FIRST and UNPREFIXED, so `browser_node_for`'s
#    hierarchy walk (item 12) still lands on the current DB's nodes: it scans in
#    row order and breaks on the first exact match. TWO-PANE item 15 keeps BOTH
#    halves — the current DB gets a header, but its rows do not move.
# A group with NO entries emits NO header: an empty `bd_a.raw (tran)` node would
# claim a DB matched when it did not.
#
# `root` (item 2, OPTIONAL) is the FALLBACK design-root label for a group that
# names none of its own, so each DB gets its own design root: the current DB's
# stays `g:`, and a foreign one goes through browser_rows_reparent, which re-keys
# it to `d:N|g:` and re-parents it (its parent is {}) onto the DB header. That is
# what lets R7 give one design root PER DB without an id collision — and a shared
# `g:` THROWS in ttk (`Item ... already exists`), on the searchbar's <KeyRelease>
# pump, i.e. bgerror, i.e. a modal dialog under X.
proc wviewer::browser_rows_multi {groups {root {}}} {
  set rows {}
  foreach g $groups {
    lassign $g gid glab gent grt gpfx
    if {$grt eq {}} { set grt $root }
    if {$glab eq {}} {
      foreach r [wviewer::browser_rows $gent $grt] { lappend rows $r }
      continue
    }
    if {![llength $gent]} { continue }
    if {[llength $g] < 5} { set gpfx "$gid|" }
    lappend rows [dict create id $gid parent {} text $glab kind group name {}]
    foreach r [wviewer::browser_rows_reparent \
                 [wviewer::browser_rows $gent $grt] $gpfx $gid] {
      lappend rows $r
    }
  }
  return $rows
}

# The row `id`'s kind (`group` / `leaf`), or {} when no such row. PURE.
proc wviewer::browser_kind {rows id} {
  foreach r $rows {
    if {[wviewer::dget $r id {}] eq $id} { return [wviewer::dget $r kind {}] }
  }
  return {}
}

# Every FULL RAW NAME at or under row `id`, in row order. A leaf answers with
# itself; a group answers with every leaf beneath it, however deep. PURE — which
# is what makes "the Plot button plots a whole group" testable without Tk.
#
# ⚠ "ROW ORDER" IS browser_rows' FIRST-APPEARANCE ORDER — i.e. RAW-FILE ORDER —
# and that is NOT always the tree's visual top-to-bottom order. ttk re-parents a
# late arrival under the group it belongs to, so a raw listing
# `v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)` DRAWS the two `x1.x2` leaves adjacent while
# this proc still returns them first-and-last. Plotting a group therefore plots
# in raw order, not in the order the rows appear on screen. Declared (receipt
# D7) rather than silently ordered either way.
#
# Rows are ordered parent-before-child, so ONE forward pass propagates
# membership: a row is included when it IS the id or when its parent already is.
proc wviewer::browser_leaf_names {rows id} {
  set out {}
  foreach s [wviewer::browser_leaf_specs $rows $id] { lappend out [lindex $s 0] }
  return $out
}

# PURE. The REGISTRY INDEX a row id belongs to, or {} for the current database.
#
# Item 14 gives every FOREIGN database's rows the prefix `d:<registry idx>|`
# (`browser_rows_multi` -> `browser_rows_reparent`) while the current DB's rows
# stay UNPREFIXED — that is the property `browser_node_for`'s hierarchy walk
# leans on, and it is what makes {} mean "current" here rather than "unknown".
# It is `browser_id_split`'s FIRST half, so the two cannot drift about what a
# prefix looks like — they are now literally the same decode read twice (§F item
# F6; before it they were two copies of one regexp with a comment asking the
# reader to keep them equal).
proc wviewer::browser_row_db {id} {
  return [lindex [wviewer::browser_id_split $id] 0]
}

# --- spec §F, RULING F4: WHICH KIND OF DATABASE DOES **THIS ROW** COME FROM? --
#
# A row id -> the `sim_type` of the database that row belongs to, out of the
# snapshot `browser_reload` already took. `{}` for a row whose database is not in
# the snapshot, which `db_is_digital` reads as ANALOG — the same deliberate
# degradation direction the current-database reader documents, and for the same
# reason: a guessed "digital" stops declassing a real ngspice raw.
#
# ⚠⚠ WHY THIS EXISTS AND THE CURRENT DATABASE'S KIND IS **NOT** ENOUGH. The tree
# is the one surface that holds SEVERAL databases at once (item 14), so "which
# grammar do this row's names obey" is a per-ROW question and answering it with
# the current database's kind is wrong in BOTH directions: with an analog raw
# current it declasses a foreign VCD's `m.sub.sig` down to `sub` (the defect
# RULING F4 exists to remove, one database over), and with a VCD current it stops
# declassing a foreign ngspice raw and answers `m.x1.xm1` for a MOSFET internal
# node whose real path is `x1.xm1` — a fresh defect pointing the other way.
#
# ⚠⚠ AND THE LOWER PANE ASKS IT TOO, SINCE §F item F6 (issue 0308). Until F6 it
# had no such question: it drew the current database's entries and only those
# (two-pane item 15's declared limit), so its own resolvers were told the current
# kind directly, and the comment here said exactly that. RULING F6 overturned it
# — the pane now draws whichever database the selected ROW belongs to — so
# `browser_sea_refresh`, `browser_sea_own` and `browser_sea_target_path` are all
# callers of THIS proc, asking it of the row `browser_sea_row` recorded (or of
# `{}`, which maps back to the current kind, so every pre-F6 state is unmoved).
#
# ⚠ WITH All-DBs TICKED THE CURRENT DATABASE'S ROWS ARE PREFIXED TOO (item 15
# gives it a header like any other), so the first branch is reached on a real
# tree and is not defensive padding — `browser_reload` captures the current DB's
# `d:<idx>` id in the same pass as the foreign ones exactly so it can be matched
# here.
proc wviewer::browser_id_type {token id} {
  variable browsercurdb
  variable browserdbsigs
  set n [wviewer::browser_row_db $id]
  if {$n eq {}} { return [wviewer::browser_curtype $token] }
  if {[info exists browsercurdb($token)] && \
      [wviewer::dget $browsercurdb($token) id {}] eq "d:$n"} {
    return [wviewer::dget $browsercurdb($token) type {}]
  }
  if {[info exists browserdbsigs($token)]} {
    foreach db $browserdbsigs($token) {
      if {[wviewer::dget $db id {}] eq "d:$n"} {
        return [wviewer::dget $db type {}]
      }
    }
  }
  return {}
}

# PURE. Every leaf at or under row `id` as `{<full raw name> <db-index-or-{}>}`,
# in row order.
#
# ⚠⚠ THE DATABASE IS PART OF THE ANSWER, AND THAT IS DEFECT 2's WHOLE FIX. The
# tree row id ALREADY says which database the user pointed at — with two VCDs
# holding `TOP.m.sig`, item 14 emits `d:1|s:TOP.m.sig` AND `d:2|s:TOP.m.sig`.
# `browser_leaf_names` threw that half away, so a double-click under the blockB
# header plotted blockA's waveform (`resolve_signal_db` resolves by NAME and
# returns the lowest-index match), with no error and no cue; and a Plot with BOTH
# rows selected deduplicated down to ONE trace. This is not exotic — it is
# exactly the shape spec §E produces when two `d_cosim` blocks instantiate the
# same Verilog module.
#
# `browser_leaf_names` is kept as the ONE-LINE PROJECTION of this proc rather
# than being deleted: `browser_menu_names` (the context menu, which ends in the
# Add Trace… dialog's TEXT ENTRY — a string the user may edit, which genuinely
# cannot carry a database) wants only the names, and so do the two-pane and
# item-14 suites that assert on it directly. Re-deriving it here means the two
# can never disagree about membership or order.
#
# Rows are ordered parent-before-child, so ONE forward pass propagates
# membership: a row is included when it IS the id or when its parent already is.
proc wviewer::browser_leaf_specs {rows id} {
  array set inc {}
  set inc($id) 1
  set out {}
  foreach r $rows {
    set rid [wviewer::dget $r id {}]
    set par [wviewer::dget $r parent {}]
    if {$par ne {} && [info exists inc($par)]} { set inc($rid) 1 }
    if {![info exists inc($rid)]} { continue }
    if {[wviewer::dget $r kind {}] ne {leaf}} { continue }
    lappend out [list [wviewer::dget $r name {}] [wviewer::browser_row_db $rid]]
  }
  return $out
}

# ONE searchbar dict applied to a name list. `{}` (a torn-down or absent bar)
# is the identity, so a browser whose filter bar has gone still searches.
# Returns sig_match's own {ok <names>} / {err <msg>}.
#
# ⚠⚠ `key` IS OPTIONAL AND DEFAULTED, AND THAT SHAPE IS LOAD-BEARING RATHER THAN
# A STYLE CHOICE (two-pane item 20 §4.2). This proc and `browser_and` are pinned
# as PURE by BT14 (5 checks), BT15 (3) and BT16 (4) — twelve checks that call
# them directly with RAW patterns against RAW names, because they are testing
# the MATCHER, not the bars. Make the label transform unconditional here and all
# twelve move for no reason; keyed-and-defaulted, they stay green BY
# CONSTRUCTION. "Make the key unconditional in browser_match_one" is a declared
# sabotage precisely so that claim is run rather than believed.
proc wviewer::browser_match_one {sigs d {key {}}} {
  if {![llength $d]} { return [list ok $sigs] }
  return [wviewer::sig_match $sigs [wviewer::dget $d pattern {}] \
            -syntax [wviewer::dget $d syntax shell] \
            -case   [wviewer::dget $d case 0] \
            -type   [wviewer::dget $d type all] \
            -key    $key]
}

# ⚠⚠ THE AND, AND THE ONLY PLACE IT LIVES. `d1` is the top Search bar, `d2` the
# bottom Filter bar (settled decision 5 / ruling 20).
#
# The AND *IS* THE CHAINING: the second bar filters the FIRST BAR'S OUTPUT,
# never the original list. Written as two explicit calls rather than a loop so
# that the one line carrying the whole claim — `[lindex $r1 1]` as the second
# call's input — is visible, greppable and singly sabotageable. Feeding `$sigs`
# there instead turns the AND into "whatever the filter bar says", which no
# count of rows can see when the two patterns happen to overlap.
#
# It also ANDs the two `-type` dropdowns for free, because each call applies its
# own bar's type to the survivors of the other's.
#
# An `err` from EITHER bar short-circuits with that bar's message (decision 4:
# an invalid regexp is an ERROR, never a silent match-all).
# ⚠ item 20's `key` is threaded to BOTH rungs, and the two-line body is the
# whole guarantee: passing it to one call and not the other makes the two bars
# disagree about what they are matching, which is the exact failure this proc's
# single-place-for-the-AND design exists to prevent. It is a declared sabotage.
proc wviewer::browser_and {sigs d1 d2 {key {}}} {
  set r1 [wviewer::browser_match_one $sigs $d1 $key]
  if {[lindex $r1 0] ne {ok}} { return $r1 }
  set r2 [wviewer::browser_match_one [lindex $r1 1] $d2 $key]
  return $r2
}

# === signal-browser PLAN item 13: the LOCATION BAR + the last-20 raw history ==
#
# ViVA's Location field (§3.1): an editable path entry at the top of the sidebar
# whose <Return> LOADS that raw, a dropdown of the last 20 raws opened (newest
# first, deduped, persisted), and `select_raw` KEPT as the Browse... button
# beside it — this item replaces nothing.
#
# ⚠ THE PLAN'S PERSISTENCE PREMISE WAS FALSE and the substitution is deliberate.
# "persisted in the config the same way other viewer prefs are" describes a
# mechanism that does not exist: no wviewer pref was persisted anywhere before
# this item. The nearest REAL house precedent is the recent-files cluster
# (xschem.tcl load_recent_file / update_recent_file / write_recent_file): a
# Tcl-sourceable file under $USER_CONF_DIR, loaded once at startup, written
# through a gated writer. That shape is what is copied here, including its gate.

# The store's file. Derived at CALL TIME, never cached: a test can repoint
# $::USER_CONF_DIR at a scratch dir and get a real end-to-end write without ever
# touching the user's ~/.xschem (test_wave_sigbrowser_i1315.tcl BR50/BR54).
proc wviewer::rawhist_path {} {
  if {![info exists ::USER_CONF_DIR] || $::USER_CONF_DIR eq {}} { return {} }
  return [file join $::USER_CONF_DIR raw_history]
}

# The cap. $::raw_history_max (registered in xschem.tcl beside the other
# user-history vars); anything that is not a positive integer falls back to 20
# rather than truncating the list to nothing or throwing.
proc wviewer::rawhist_max {} {
  if {![info exists ::raw_history_max]} { return 20 }
  set m $::raw_history_max
  if {![string is integer -strict $m] || $m <= 0} { return 20 }
  return $m
}

# PURE: `hist` with `path` moved to the FRONT, deduped on the NORMALISED path,
# truncated to `max`. No widget, no `xschem`, no file I/O and no namespace
# variable — which is what lets every ordering/dedup/cap claim be checked in the
# `--nogui` arm, where there is no Tk and no raw at all.
#
# ⚠ THE DEDUP COMPARES `file normalize`D FORMS, not literals. `/a/b`, `/a/./b`
# and `/a/b/` are one raw file and must be ONE entry; a literal `ne` would let
# the same file occupy all twenty slots. Sabotage (a) removes exactly this.
proc wviewer::rawhist_add {hist path {max 20}} {
  if {$path eq {}} { return $hist }
  set p [file normalize $path]
  if {$p eq {}} { return $hist }
  set out [list $p]
  foreach i $hist {
    if {$i eq {}} { continue }
    if {[file normalize $i] eq $p} { continue }
    lappend out $i
  }
  if {![string is integer -strict $max] || $max <= 0} { set max 20 }
  # tcl8.4 errors if using lreplace past the last element (update_recent_file)
  if {[llength $out] > $max} { set out [lreplace $out $max end] }
  return $out
}

proc wviewer::rawhist_get {} {
  variable rawhist
  return $rawhist
}

# Read the store at startup. NEVER THROWS and never warns: a corrupt or
# half-written raw_history must not stop xschem starting, and unlike
# recent_files there is no user-visible menu whose absence would go unnoticed —
# the dropdown simply comes up empty.
proc wviewer::rawhist_load {} {
  variable rawhist
  set f [wviewer::rawhist_path]
  if {$f eq {} || ![file exists $f]} { return 0 }
  if {[catch {source $f}]} { return 0 }
  if {![info exists rawhist]} { set rawhist {} }
  return [llength $rawhist]
}

# Write the store. Same `set <fully qualified var> {<list>}` line shape as
# write_recent_file, so the file is plain `source`able (and readable by a test
# into a throwaway namespace).
#
# ⚠⚠ `::open` AND `::close` ARE FULLY QUALIFIED ON PURPOSE, AND THIS WAS A REAL
# BUG BEFORE IT WAS A COMMENT. This namespace defines `wviewer::open {token}`
# and `wviewer::close {token}`, and Tcl resolves an unqualified command name in
# the CURRENT NAMESPACE FIRST — so a bare `open $f w` here called
# `wviewer::open` with two arguments, threw "wrong # args", and the `catch`
# swallowed it: `rawhist_write` returned 0 forever and no store was ever
# written, while every structural check stayed green. Exactly item 10's
# `clipboard clear` defect (its bare call resolved to `wviewer::clipboard`), and
# it was caught the same way — by a check that READ THE FILE BACK OFF DISK
# rather than one that observed a non-throwing return.
proc wviewer::rawhist_write {} {
  variable rawhist
  set f [wviewer::rawhist_path]
  if {$f eq {}} { return 0 }
  if {[catch {::open $f w} fd]} { return 0 }
  catch {puts $fd "set ::wviewer::rawhist {$rawhist}"}
  catch {::close $fd}
  return 1
}

# THE ONLY GATED SITE. Returns 1 when the history actually moved.
#
# ⚠ THE GATE IS `update_recent_files`, DELIBERATELY THE SAME FLAG THE
# RECENT-FILES CLUSTER USES, and a private flag would REOPEN ISSUE 0119. That
# flag is the only one covering BOTH halves of the problem: C forces it 0 for a
# hard-gated automation session (--nogui / --pipe / --norecent, xschem.tcl
# :15752 off `no_recent_files`) AND toggles it 0 around `source_tcl_file` for
# the duration of a --script BODY in an otherwise ungated GUI session
# (xinit.c :3809). A verification run must not rewrite the user's history.
#
# It suppresses the IN-MEMORY append as well as the disk write — update_recent_file
# parity. A gated session that appended in memory and merely declined to write
# would still hand the next interactive write a polluted list.
proc wviewer::rawhist_push {path} {
  variable rawhist
  # the recent-views list belongs to the user: no-op in gated (test/automation)
  # sessions -- issue 0119, the same flag update_recent_file gates on
  if {[info exists ::update_recent_files] && !$::update_recent_files} { return 0 }
  set new [wviewer::rawhist_add $rawhist $path [wviewer::rawhist_max]]
  if {$new eq $rawhist} { return 0 }
  set rawhist $new
  wviewer::rawhist_write
  return 1
}

# item 15: fold a SAVED history back into the live one. THE SECOND GATED SITE,
# and it carries `rawhist_push`'s gate line VERBATIM and for the identical
# reason: a restore is something a `--script` verification run does constantly,
# and issue 0119 is precisely such a run rewriting a user file. Without this
# line, restoring a state dict in a headless suite would write
# `~/.xschem/raw_history`.
#
# ⚠ IT MERGES, IT DOES NOT REPLACE. `rawhist` is ONE GLOBAL disk-backed list
# shared by every open viewer (rawbar_sync fans the dropdown out to all of
# them), so a restore that assigned the saved list would silently delete raws
# opened in another window since the snapshot was taken.
#
# Every ordering/dedup/cap rule comes from item 13's PURE `rawhist_add` — folded
# OLDEST-FIRST so the saved list's newest entry ends up nearest the front, with
# the live entries it does not mention keeping their relative order behind it.
# Nothing here re-implements normalise, dedup or the 20-cap.
#
# ⚠ AN INDEX LOOP, NOT `lreverse`: `lreverse` is Tcl 8.5+ and this repo targets
# 8.4-8.6 (see rawhist_add's own 8.4 note on `lreplace`).
# Returns 1 when the live list actually moved.
proc wviewer::rawhist_merge {saved} {
  variable rawhist
  # the recent-views list belongs to the user: no-op in gated (test/automation)
  # sessions -- issue 0119, the same flag rawhist_push and update_recent_file gate on
  if {[info exists ::update_recent_files] && !$::update_recent_files} { return 0 }
  if {![llength $saved]} { return 0 }
  set new $rawhist
  for {set i [expr {[llength $saved] - 1}]} {$i >= 0} {incr i -1} {
    set new [wviewer::rawhist_add $new [lindex $saved $i] [wviewer::rawhist_max]]
  }
  if {$new eq $rawhist} { return 0 }
  set rawhist $new
  wviewer::rawhist_write
  return 1
}

# Push the current path into the combobox, refresh its -values from the history
# and RE-ATTACH the balloon.
#
# ⚠ MUST NOT THROW: it rides <Return> and <<ComboboxSelected>>, and a Tcl error
# on a binding pops bgerror — modal under X, which hangs a headless run. Same
# discipline as browser_refresh and searchbar_fire: every step `catch`ed.
#
# ⚠ THE BALLOON IS RE-ATTACHED, NOT ATTACHED ONCE. `balloon` BAKES ITS STRING IN
# at bind time (xschem.tcl :12551 builds the <Enter> script by substitution), so
# a balloon attached at build time would forever show the path the bar held when
# the sidebar was built. The full path in the tooltip is the whole answer to the
# Eyeball clause: the entry itself shows only the tail.
#
# ⚠ IT FANS THE DROPDOWN OUT TO EVERY OTHER OPEN VIEWER, and that is not a
# nicety: `rawhist` is ONE GLOBAL LIST, so a second viewer window whose sidebar
# was built earlier would otherwise keep its build-time `-values` for the rest of
# the session — the user opens a raw in window A and window B's "last 20 raws"
# never hears about it. Only the -values are fanned out. The ENTRY TEXT and the
# BALLOON stay per-window because they name THAT window's OWN current raw, which
# a load in another window did not change. BR28/BR29 assert both halves.
proc wviewer::rawbar_sync {token {path {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set cb [dict get $windows $token top].wvbrowser.loc.cb
  set rc 0
  if {![catch {winfo exists $cb} e] && $e} {
    if {$path ne {}} {
      catch {$cb set $path}
    } else {
      catch {set path [$cb get]}
    }
    catch {$cb configure -values [wviewer::rawhist_get]}
    catch {balloon $cb [expr {$path eq {} ? {(no raw file loaded)} : $path}]}
    set rc 1
  }
  foreach t [dict keys $windows] {
    if {$t eq $token} { continue }
    set c2 {}
    catch {set c2 [dict get $windows $t top].wvbrowser.loc.cb}
    if {$c2 eq {}} { continue }
    if {[catch {winfo exists $c2} e2] || !$e2} { continue }
    catch {$c2 configure -values [wviewer::rawhist_get]}
  }
  return $rc
}

# LOAD the raw named by the Location bar. Returns 1 on success, 0 on every
# refusal — and every refusal leaves the previous raw AND the tree exactly as
# they were.
#
# ⚠ IT DOES NOT `raw clear` FIRST, and that is a DELIBERATE DIVERGENCE from
# `attach_raw` (:2529), whose first act is `catch {xschem raw clear}`. MEASURED:
# with A current, `xschem raw read <garbage>` returns 0 and leaves both
# `raw rawfile` and `raw list` on A — the engine's read is atomic as long as
# nothing cleared the old data first. Clearing would turn a typo in an editable
# path entry into "your waveforms are gone". The cost is declared: raws
# ACCUMULATE in xctx->extra_raw_arr rather than replacing one another.
#
# ⚠ THE `browser_refresh $token 1` IS NOT OPTIONAL — item 9's declared limit D6
# says the inventory is a SNAPSHOT taken when the sidebar is SHOWN, and
# `browser_show`'s pack branch was its ONLY caller. Without this line the user
# gets the new raw's waveforms under the OLD raw's signal list. It is placed
# after the successful read and inside it, so a failed read cannot replace a
# good tree with an empty one (item 12's improve-or-restore guarantee, reached
# here by never starting the reload at all).
proc wviewer::rawbar_load {token path} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set path [string trim $path]
  if {$path eq {}} {
    wviewer::browser_status $token {Location: type the path of a raw file}
    return 0
  }
  if {![file isfile $path]} {
    wviewer::browser_status $token "Location: no such file '[file tail $path]'"
    return 0
  }
  # attach_raw's precedent: a MOVE, not a 0173 loan. `regenerate` goes through
  # `with_edit`, which deliberately does not restore the context.
  if {![wviewer::switch_ctx $token]} { return 0 }
  # issue 0194 / test_wave_grid's GX1 rule: a Location-bar load replaces the
  # DATA, not the plot — strips, traces and the selection all carry forward, so
  # the regenerate below owes the fold, and skip_ranges is what keeps the new
  # raw autozooming instead of being drawn in the outgoing raw's window.
  wviewer::capture_live_view_state $token
  set rc 0
  catch {set rc [xschem raw read $path]}
  if {$rc != 1} {
    wviewer::browser_status $token "Location: could not read '[file tail $path]'"
    return 0
  }
  wviewer::regenerate $token
  catch {wviewer::browser_refresh $token 1}
  wviewer::rawhist_push $path
  wviewer::rawbar_sync $token $path
  wviewer::log_action [list wviewer::rawbar_load $token $path]
  return 1
}

# ONE COMMIT PATH (searchbar_fire's rule): both bindings and the Browse button
# end in `rawbar_load`, so no route can apply a policy another route skips.
proc wviewer::rawbar_commit {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set cb [dict get $windows $token top].wvbrowser.loc.cb
  set p {}
  if {[catch {set p [$cb get]}]} { return 0 }
  return [wviewer::rawbar_load $token $p]
}

# Browse... — `select_raw` (xschem.tcl :14290) REUSED, not reimplemented. It is
# `tk_getOpenFile`, i.e. MODAL, so this route is never exercised headlessly;
# only its wiring is assertable (declared limit).
proc wviewer::rawbar_browse {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set p {}
  if {[catch {select_raw $top} p]} { return 0 }
  if {$p eq {}} { return 0 }
  return [wviewer::rawbar_load $token $p]
}

# Build the (HIDDEN) sidebar. Out of `open` for the same reason `tabbar_build`
# is: a viewer that never opens the browser keeps its canvas geometry
# BYTE-IDENTICAL to the pre-item-8 viewer, which every viewport-derived
# assertion in the wave suites (band_geometry, graphbb, viewport_rect) depends
# on. Returns 1.
#
# item 9 fills it: the top Search bar, a Plot toolbar, the tree, the bottom
# Filter bar, and item 8's placeholder label REPURPOSED as the status/error
# line at the very bottom (which is also decision 4's second display surface —
# see browser_refresh).
proc wviewer::browser_build {token top} {
  variable browser
  variable browsersigs
  variable browserrows
  # TWO-PANE item 9: R11's two class filters. DECLARED, or the seeding below
  # writes a LOCAL array and the checkbuttons bind to a namespace variable that
  # nothing ever set -- which reads as (b) defaulting OFF, the one value R11
  # rules against.
  variable browserdev
  variable browsersrc
  catch {destroy $top.wvbrowser}
  # ⚠ ISSUE 0312: THE GRIP GOES WITH IT, and the failure without this line is
  # not merely an orphan. `browser_build` re-creates the sidebar UNPACKED and
  # sets `browser($token) 0` without calling `browser_show`, so a grip left
  # packed sits against no sidebar at all -- and the NEXT show packs the sidebar
  # `-before $top.drw`, i.e. AFTER the grip in the slave order, putting the
  # divider on the wrong side of the pane it resizes.
  catch {destroy $top.wvbgrip}
  set f $top.wvbrowser
  frame $f -background [ase::theme panel] -takefocus 0
  label $f.ph -anchor nw -justify left -width 22 \
    -font AseLabelFont -background [ase::theme panel] \
    -text "Signal Browser\n(empty)"
  # --- item 13: the LOCATION ROW ---------------------------------------------
  # ⚠ `-side right` FIRST, and it is forced by item 9's D1, not taste.
  # `browser_width` sets `pack propagate $f 0` and then FIXES the frame's width
  # (a measured 583 px, floored at 240), so a child wider than that is CLIPPED,
  # never accommodated. The packer serves slaves in packing order, so the
  # fixed-width Browse button must claim its slot before the stretchy entry.
  #
  # ⚠ THE COMBOBOX IS `-width 18` AND `-justify right`, which is the whole of
  # the long-path answer: the fixed width stops the packer's reqwidth growing
  # with the text (a full raw path is easily 120 characters), and right
  # justification means the part that stays on screen is the TAIL — the file
  # name — rather than a useless run of leading directories. The full path
  # lives in the balloon, re-attached by rawbar_sync on every load.
  frame $f.loc -background [ase::theme panel]
  button $f.loc.br -text {Browse...} -font AseLabelFont \
    -command [list wviewer::rawbar_browse $token]
  ttk::combobox $f.loc.cb -width 18 -justify right \
    -values [wviewer::rawhist_get]
  pack $f.loc.br -side right -padx {0 6} -pady 2
  pack $f.loc.cb -side left -fill x -expand 1 -padx {6 4} -pady 2
  bind $f.loc.cb <Return>             [list wviewer::rawbar_commit $token]
  bind $f.loc.cb <<ComboboxSelected>> [list wviewer::rawbar_commit $token]
  # THE TOP BAR KEEPS ITS SEARCH BUTTON (ruling 20); the BOTTOM one is the
  # `-showbutton 0` variant that ruling reserved, and item 9 is its first user.
  # `-fill x` on both is item 4's stated requirement.
  # item 14: `-alldbs 1` on the TOP bar ONLY. The bottom Filter bar narrows a
  # list that has ALREADY been fetched, so a DB scope there would mean nothing —
  # and two boxes would be two answers to one question.
  # ⚠ IT GOES AFTER `-command`, NOT BEFORE. Options are order-independent to
  # searchbar_build (a `foreach {o v}` loop), but item 9's BT05 is a SOURCE grep
  # pinned to the literal `searchbar_build $f -command [list
  # wviewer::browser_search_cb`, and test_wave_sigbrowser.tcl is FROZEN by
  # ruling 30. Inserting an option in front of `-command` turned that check red
  # for no behavioural reason; appending keeps item 9's coverage exactly as
  # shipped and costs nothing.
  wviewer::searchbar_build $f -command [list wviewer::browser_search_cb $token] -alldbs 1
  frame $f.tb -background [ase::theme panel]
  button $f.tb.plot -text Plot -font AseLabelFont \
    -command [list wviewer::browser_plot_selection $token]
  pack $f.tb.plot -side left -padx {6 4} -pady 2
  # --- TWO-PANE item 9: R11's TWO CLASS FILTERS, BUILT INERT ------------------
  # Two independent boxes with two DIFFERENT defaults (spec R11): device
  # internals OFF, source currents ON. They are seeded BEFORE the widgets are
  # created, because a ttk::checkbutton whose -variable does not exist yet
  # creates it at the OFF value -- which would silently give (b) the wrong
  # default and no check would see the difference between "ruled 1" and
  # "happened to be 0".
  #
  # ⚠ TWO-PANE ITEM 12 WIRED THEM. Item 9 built them with `-command {}` and said
  # so here; that is no longer true and the note is kept rather than deleted
  # because BW25 was written against the inert shape and item 12 had to RESTATE
  # it (the PLAN's "item 12 reds nothing" was wrong). BOTH boxes get the SAME
  # command -- one refresh, one consistent set (spec §6) -- and it is
  # `browser_refresh`, NOT `browser_reload`: a toggle re-scopes the snapshot the
  # browser already holds and must never re-enter the engine (BW63's spy).
  #
  # ⚠ STILL NO ACCELERATOR AND STILL NOT A MENU ENTRY. A checkbutton uses
  # -command rather than `bind $f.`, so neither box moves the guide's GH8/GH9
  # gesture count or GH0's 11 accelerators, and wiring them did not change that.
  #
  # ⚠ They are OPTIONS ON THE SIDEBAR, not options on searchbar_build: BAR11
  # pins the plain bar's dict to exactly four keys and `searchbar_get` already
  # emits one conditional key, so a fifth would be blast radius for no gain
  # (spec §6).
  set browserdev($token) 0
  set browsersrc($token) 1
  frame $f.opt -background [ase::theme panel]
  ttk::checkbutton $f.opt.dev -text {Show device internals} \
    -variable ::wviewer::browserdev($token) \
    -command [list wviewer::browser_refresh $token]
  ttk::checkbutton $f.opt.src -text {Show source currents} \
    -variable ::wviewer::browsersrc($token) \
    -command [list wviewer::browser_refresh $token]
  pack $f.opt.dev -side top -anchor w -padx 6
  pack $f.opt.src -side top -anchor w -padx 6
  # --- TWO-PANE item 9: THE PANED SKELETON ------------------------------------
  # M3: STACKED, not side by side, and the reason is measured rather than
  # aesthetic -- `browser_width` already caps the sidebar at 0.45 x window
  # (~450 px at the 1000x829 spawn size), so a side-by-side split halves an
  # already-narrow pane. Stacked fits 14+18 rows spawned, 23+36 maximized.
  #
  # ⚠ `$f.pw` IS A CHILD OF `$f`, AND THAT IS LOAD-BEARING RATHER THAN
  # INCIDENTAL. `browser_width` fixes the width of `$f` with `pack propagate 0`;
  # every pane inherits it because every pane is inside `$f`. Re-parent `$f.pw`
  # to the toplevel and BT08's and BP07's four width literals -- all SOURCE
  # greps -- stay green while the sidebar silently stops governing the panes.
  # That sabotage was RUN; the checks that catch it are BW31/BW32, which read a
  # live widget (doc/claude/signal_browser_2pane_batch/PLAN.md §3 trap 1).
  ttk::panedwindow $f.pw -orient vertical
  frame $f.pw.tvf -background [ase::theme panel]
  # R4: `browse`, i.e. exactly one node selected at all times.
  # ⚠ M4: `-stretch 0` WITH AN EXPLICIT WIDTH, and `-xscrollcommand`, as ONE
  # change. Inside `pack propagate 0` a `-stretch 1` column always fits the
  # widget, so an h-scrollbar added without the stretch change scrolls nothing
  # and is pure decoration. MEASURED on Tk 8.6.14: at a 570 px tree, `-stretch 1`
  # grows column #0 from 200 to 568 and `xview` is `{0.0 1.0}` whatever the tree
  # holds; `-stretch 0` leaves it at 200. ⚠ ttk does NOT auto-grow #0 for deep
  # or long items either -- depth is not the discriminator, the stretch flag is.
  ttk::treeview $f.pw.tvf.tv -show tree -selectmode browse -style Ase.Treeview \
    -yscrollcommand [list $f.pw.tvf.sb set] \
    -xscrollcommand [list $f.pw.tvf.hsb set]
  $f.pw.tvf.tv column #0 -width 200 -minwidth 80 -stretch 0
  scrollbar $f.pw.tvf.sb -command [list $f.pw.tvf.tv yview]
  scrollbar $f.pw.tvf.hsb -orient horizontal -command [list $f.pw.tvf.tv xview]
  pack $f.pw.tvf.sb  -side right  -fill y
  pack $f.pw.tvf.hsb -side bottom -fill x
  pack $f.pw.tvf.tv  -side left   -fill both -expand 1
  wviewer::browser_sea_build $f.pw
  # tree on TOP (M3), both panes stretchy so the sash starts where
  # `browser_sash` puts it rather than where the request sizes land.
  $f.pw add $f.pw.tvf -weight 1
  $f.pw add $f.pw.sea -weight 1
  wviewer::searchbar_build $f -name wvfilter -showbutton 0 \
    -command [list wviewer::browser_filter_cb $token]
  # item 13: the Location row sits ABOVE the Search bar (ViVA §3.1's order)
  pack $f.loc      -side top -fill x
  pack $f.wvsearch -side top -fill x
  pack $f.tb       -side top -fill x
  # bottom-up: the status line last of all, the Filter bar just above it
  pack $f.ph       -side bottom -fill x -padx 4 -pady 4
  pack $f.wvfilter -side bottom -fill x
  # ⚠ `.opt` IS PACKED `-side top` AFTER THE TWO `-side bottom` ROWS, and the
  # order is the layout. `pack slaves` reports PACKING order, which for a mixed
  # top/bottom stack is not the visual order: packing `.opt` here puts R11's two
  # boxes directly under the Plot toolbar, and `.pw` -- packed last with
  # `-expand 1` -- then takes everything left between the boxes and the Filter
  # bar. Pinned as a whole recipe by BT21 and its local twin BR21.
  pack $f.opt      -side top -fill x
  pack $f.pw       -side top -fill both -expand 1
  # ⚠ NO `break` ON EITHER, and that is MEASURED rather than assumed: the
  # bindtags of a treeview inside a viewer toplevel are {<tv> Treeview <top>
  # all}. The CANVAS is not among them (set_bindings binds win_path, not the
  # toplevel), so xschem.tcl's canvas-level <Double-Button-1> cannot fire here;
  # the toplevel carries only Expose/Visibility/FocusIn; and `bind all` has
  # nothing relevant. Letting ttk's own Double-1 run is therefore harmless, and
  # it is exactly what keeps group expand/collapse working. Pinned by BT34.
  #
  # The trailing 0/1 is the GROUPS flag: a double-click on a group must NOT
  # plot (ttk's expand/collapse owns that gesture), MMB and the Plot button do.
  bind $f.pw.tvf.tv <Double-Button-1> \
    [list wviewer::browser_plot_at $token %W %x %y 0]
  bind $f.pw.tvf.tv <Button-2> \
    [list wviewer::browser_plot_at $token %W %x %y 1]
  # item 10: the RMB context menu. ⚠ THE `break` IS DEFENCE IN DEPTH, NOT THE
  # MECHANISM — see browser_menu_ids' block comment. What keeps xschem's canvas
  # RMB out of this widget is the bindtag chain ({<tv> Treeview <top> all}, no
  # canvas in it, no Button-3 on any of the other three), measured by BM35 and
  # BM42; the `break` guards only against a future toplevel/all-level Button-3.
  # Kept, and named honestly in BM01, rather than quietly dropped.
  bind $f.pw.tvf.tv <Button-3> \
    "[list wviewer::browser_menu_post $token] %W %x %y %X %Y ; break"
  # item 11: `Descend to here` ON THE TREE ITSELF. Required, not duplicated for
  # taste: the tree's bindtags are {<tv> Treeview <top> all} and the CANVAS is
  # not among them, so the WaveViewer-tag <Key-E> only fires while the canvas
  # has focus — and the user pressing this key has just clicked a row, i.e. the
  # tree has focus. Both routes resolve the same target (the tree's selection)
  # through browser_descend_at. The `break` stops ttk seeing it.
  bind $f.pw.tvf.tv <Key-E> {wviewer::browser_descend_at %W ; break}
  # item 10 (two-pane): the tree's selection IS the lower pane's query. The bind
  # lands here, in the SAME commit as its guide row, so GH8/GH9's count moves
  # exactly once. `browser_sea_refresh` is a stub until item 11 — the shape
  # stops moving now, the behaviour arrives later.
  bind $f.pw.tvf.tv <<TreeviewSelect>> [list wviewer::browser_sea_refresh $token]
  # --- item 11: the LOWER pane's seven gestures (spec §5.3 + the reflow) ------
  # They live HERE, in browser_build, and not in browser_sea_build, because
  # GH8/GH9 count `bind $f.` lines in THIS proc against the guide's data-bseq
  # rows: a gesture bound out of sight of that ledger is a gesture nobody
  # documents. The widget is spelled `$f.pw.sea.c` for the same reason.
  #
  # ⚠ NO `break` ON ANY OF THEM, and unlike the tree that is not a choice about
  # defence in depth — a canvas inside the sidebar has bindtags
  # {<canvas> Canvas <top> all} and Tk's stock Canvas class binds none of these,
  # so there is nothing to yield to and nothing to stop.
  bind $f.pw.sea.c <Button-1> \
    [list wviewer::browser_sea_click $token %W %x %y]
  bind $f.pw.sea.c <Shift-Button-1> \
    [list wviewer::browser_sea_extend $token %W %x %y]
  bind $f.pw.sea.c <Control-Button-1> \
    [list wviewer::browser_sea_toggle $token %W %x %y]
  bind $f.pw.sea.c <Double-Button-1> \
    [list wviewer::browser_sea_plot_at $token %W %x %y]
  bind $f.pw.sea.c <Button-2> \
    [list wviewer::browser_sea_plot_at $token %W %x %y]
  bind $f.pw.sea.c <Button-3> \
    "[list wviewer::browser_sea_menu_post $token] %W %x %y %X %Y"
  bind $f.pw.sea.c <Configure> \
    [list wviewer::browser_sea_configure $token]
  # THE EIGHTH, and it pays PLAN item 11's one acknowledged miss: the pane draws
  # R8's LABEL and had no way to show the NAME behind it. Item 20 lets the user
  # filter on what they see; this tells them what they are looking at. ⚠ ONE
  # bind — the teardown is `browser_sea_tip_watch`, not a `<Leave>` that would
  # be a ninth line here documenting no gesture.
  bind $f.pw.sea.c <Motion> \
    [list wviewer::browser_sea_tip $token %W %x %y]
  # --- TWO-PANE item 14: the SPLIT ITSELF is a gesture, and the only one that
  # writes the persisted sash preference (spec §9). Without it the field is one
  # nobody can set and every round trip is a round trip of a constant.
  #
  # ⚠⚠ NO `break`, AND THAT IS MEASURED RATHER THAN ASSUMED. A ttk::panedwindow's
  # bindtags are {<pw> TPanedwindow <top> all}, so this WIDGET binding runs
  # FIRST and ttk's own class-level Release still has to run after it -- a
  # `break` here would kill sash dragging outright. (The
  # `<ButtonRelease>`-not-`<ButtonRelease-1>` rule earlier in this file is about
  # the CANVAS's kept generic editor bind; the panedwindow has no generic bind
  # to preempt, and a probe confirmed the two coexist.) BP68's third leg is the
  # standing ban.
  #
  # ⚠ THE RELEASE FIRES ONLY ON THE SASH. A release on the tree or on the sea
  # goes to THOSE widgets; neither is a `$f.pw` event.
  bind $f.pw <ButtonRelease-1> [list wviewer::browser_sash_drop $token]
  set browsersigs($token) {}
  set browserrows($token) {}
  set browser($token) 0
  wviewer::sync_browser_mirror $token
  ase::ui::apply_theme $f
  return 1
}

# =============================================================================
# TWO-PANE item 11: THE LOWER PANE GOES LIVE — the tree's selection -> the sea
# doc/claude/specs/waveform_signal_browser_two_pane.md §5, §7.1, §7.2, R3-R8.
# doc/claude/signal_browser_2pane_batch/PLAN.md item 11.
# =============================================================================
#
# The canvas the sea is drawn on, or {} — the ONE spelling of that path.
proc wviewer::browser_sea_canvas {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set c [dict get $windows $token top].wvbrowser.pw.sea.c
  if {[catch {winfo exists $c} e] || !$e} { return {} }
  return $c
}

# The row pitch, READ AT RUNTIME from the font (spec §5.2). ⚠ NEVER A CONSTANT,
# and that is measured rather than stylistic: `tk scaling` differs per display,
# so Arial 13 is 19.93 px here and something else on the next machine. The
# shipped scrollable-frame idiom hardcodes 24 px for exactly this row
# (src/xschem.tcl:1683-1685) — a coincidence of ONE machine, not a contract.
#
# The floor is for a Tk-less (`--nogui`) caller: with no font engine there is no
# display either, so answering a floor is an ANSWER, not a guess that can be
# seen.
proc wviewer::browser_sea_rowh {} {
  set ls 0
  catch {ase::theme}
  catch {set ls [font metrics AseEntryFont -linespace]}
  if {![string is integer -strict $ls] || $ls < 1} { set ls 12 }
  return [expr {$ls + 4}]
}

# The column pitch: the widest RENDERED label plus a gutter, `font measure`d,
# floored (spec §5.2). The floor is what stops a level of one-character names
# producing fifty columns of whitespace.
proc wviewer::browser_sea_colw {labels} {
  set w 0
  foreach l $labels {
    set m 0
    catch {set m [font measure AseEntryFont $l]}
    if {[string is integer -strict $m] && $m > $w} { set w $m }
  }
  incr w 18
  if {$w < 60} { set w 60 }
  return $w
}

# {per cols colw rowh n paneh} for what is CURRENTLY drawn at the CURRENT pane
# height.
#
# ⚠⚠ ONE ARITHMETIC, ONE PLACE, and this proc exists for exactly that. The draw
# and the hit-test must agree to the pixel or a click selects a neighbour; two
# copies of `colw = widest + gutter` drift the first time one of them is tuned,
# and the drift is invisible until a user clicks the last column.
proc wviewer::browser_sea_layout {token} {
  variable browsersea
  set pairs {}
  if {[info exists browsersea($token)]} { set pairs $browsersea($token) }
  set labels {}
  foreach p $pairs { lappend labels [lindex $p 0] }
  set n    [llength $pairs]
  set rowh [wviewer::browser_sea_rowh]
  set colw [wviewer::browser_sea_colw $labels]
  set paneh 1
  set c [wviewer::browser_sea_canvas $token]
  if {$c ne {}} { catch {set paneh [winfo height $c]} }
  if {![string is integer -strict $paneh] || $paneh < 1} { set paneh 1 }
  lassign [wviewer::browser_flow_layout $n $rowh $paneh] per cols
  return [list $per $cols $colw $rowh $n $paneh]
}

# --- the accessors every gesture resolves through -----------------------------
# ⚠ THE LABEL IS A DISPLAY, NEVER AN IDENTITY (spec R8, and it collides exactly
# four times in the 2656-name corpus). A gesture answers an INDEX; the index
# answers a FULL RAW NAME through here; nothing downstream ever sees a label.

# The ordered full raw names currently drawn.
proc wviewer::browser_sea_names {token} {
  variable browsersea
  if {![info exists browsersea($token)]} { return {} }
  set out {}
  foreach p $browsersea($token) { lappend out [lindex $p 1] }
  return $out
}

# ONE index -> its full raw name, {} when out of range. NEVER throws.
proc wviewer::browser_sea_name {token idx} {
  variable browsersea
  if {![info exists browsersea($token)]} { return {} }
  if {![string is integer -strict $idx]} { return {} }
  if {$idx < 0 || $idx >= [llength $browsersea($token)]} { return {} }
  return [lindex [lindex $browsersea($token) $idx] 1]
}

# The selection: a SET of indices, ascending, and always inside range. Sorting
# here rather than at every call site is what makes "extend from the anchor"
# and "toggle" produce comparable values.
proc wviewer::browser_sea_selection {token} {
  variable browsersea
  variable browserseasel
  if {![info exists browserseasel($token)]} { return {} }
  set n 0
  if {[info exists browsersea($token)]} { set n [llength $browsersea($token)] }
  set out {}
  foreach i [lsort -integer -unique $browserseasel($token)] {
    if {$i >= 0 && $i < $n} { lappend out $i }
  }
  return $out
}

# The selected FULL RAW NAMES, in flow order.
proc wviewer::browser_sea_sel_names {token} {
  set out {}
  foreach i [wviewer::browser_sea_selection $token] {
    set n [wviewer::browser_sea_name $token $i]
    if {$n ne {}} { lappend out $n }
  }
  return $out
}

# Replace the selection and redraw. `anchor` {} keeps the current one.
proc wviewer::browser_sea_select {token idxs {anchor {}}} {
  variable browserseasel
  variable browserseaanchor
  set browserseasel($token) $idxs
  if {$anchor ne {} && [string is integer -strict $anchor]} {
    set browserseaanchor($token) $anchor
  }
  wviewer::browser_sea_draw $token
  return [llength [wviewer::browser_sea_selection $token]]
}

# --- THE DRAW -----------------------------------------------------------------
# Column-major flow onto the canvas: a selection rectangle behind each selected
# cell, then the label. Returns the number of cells drawn.
#
# ⚠ THE SCROLLREGION'S HEIGHT IS CLAMPED TO THE PANE, and that clamp is the
# whole of R3's "horizontal scrollbar only" — see browser_flow_scrollregion.
# There is NO -yscrollcommand on this canvas and there must not be one.
#
# ⚠ IT MUST NEVER CALL `$tv see`, and it never touches the tree at all. That is
# R5: a search narrows THIS pane and leaves the tree's open set alone.
proc wviewer::browser_sea_draw {token} {
  variable browsersea
  variable browserseanote
  set c [wviewer::browser_sea_canvas $token]
  if {$c eq {}} { return 0 }
  catch {$c delete all}
  lassign [wviewer::browser_sea_layout $token] per cols colw rowh n paneh
  catch {$c configure -scrollregion \
           [wviewer::browser_flow_scrollregion $cols $colw $paneh]}
  if {!$n} {
    # --- §F item F5: WHY THE PANE IS EMPTY, IN THE PANE ----------------------
    #
    # ⚠⚠ ONLY WHEN THERE IS NOTHING TO DRAW. The notice explains an ABSENCE, so
    # it may never overprint names: `n == 0` is the one state in which the pane
    # is telling the user nothing at all, and it is exactly the state F5's spec
    # row names ("must say why, not show an empty pane"). The caption and the
    # CIW carry the same sentence when the pane is NOT empty (browser_notice),
    # which is the fall-through case — the analog path landed somewhere real
    # and the digital pane the user asked for is the thing that is missing.
    #
    # ⚠ `-width` IS THE PANE's WIDTH: the sentence is a whole clause naming a
    # file and a scope, and a canvas text item does not wrap without one. The
    # floor keeps it wrapping rather than vanishing in a sidebar dragged narrow.
    if {[info exists browserseanote($token)] && $browserseanote($token) ne {}} {
      set w 0
      catch {set w [winfo width $c]}
      if {$w < 80} { set w 240 }
      catch {$c create text 6 4 -anchor nw -font AseLabelFont \
               -width [expr {$w - 12}] -text $browserseanote($token) \
               -fill {#8b0000} -tags [list seanote]}
    }
    return 0
  }
  set pairs $browsersea($token)
  set sel [wviewer::browser_sea_selection $token]
  # the palette has no `select` key; `header` is the one flat tint in it and
  # `accent` the one contrast colour, so the box and the selected text come from
  # the theme rather than from two new literals nobody would ever re-tune.
  set boxbg {#e8e8e8}
  set selfg {#8b0000}
  catch {set boxbg [ase::theme header]}
  catch {set selfg [ase::theme accent]}
  for {set i 0} {$i < $n} {incr i} {
    lassign [wviewer::browser_flow_cell $i $per $colw $rowh] x y
    set on [expr {[lsearch -exact $sel $i] >= 0}]
    if {$on} {
      catch {$c create rectangle $x $y [expr {$x + $colw}] [expr {$y + $rowh}] \
               -fill $boxbg -outline {} -tags [list selbox]}
    }
    # ⚠ THE TAGS ARE `cell` AND `n<index>` — the raw name is NOT among them.
    # A canvas TAG is parsed as a tag EXPRESSION by `find withtag`, and raw
    # names carry `(`, `)`, `[`, `]` and `@`, so a name-as-tag would be a
    # search that throws on its own data. The index is the handle;
    # browser_sea_name is the decoder.
    catch {$c create text [expr {$x + 3}] $y -anchor nw -font AseEntryFont \
             -text [lindex [lindex $pairs $i] 0] \
             -fill [expr {$on ? $selfg : {#000000}}] \
             -tags [list cell n$i]}
  }
  return $n
}

# --- THE REFRESH --------------------------------------------------------------
# The tree's ONE selected node -> the names at exactly that level -> the flow.
# Returns the number of cells drawn; 0 is an ANSWER (a pure ancestor, or a
# pattern that matched nothing), never an error.
#
# ⚠⚠ IT RIDES <<TreeviewSelect>>, WHICH FIRES ON EVERY KEYSTROKE IN EITHER BAR
# (browser_populate's `selection set` fires it once per repopulate). A throw
# here pops bgerror — MODAL under X, which HANGS a headless run. Every rung is a
# guard, exactly like browser_refresh and browser_menu_post.
#
# ⚠ `browser_level_names`, NOT `browser_leaf_names`. Two different questions
# (spec §7.6): the tree's plot gesture is RECURSIVE by ruling R6 — MEASURED on
# tb_bandgap's x1, own level 43 against 172 recursive under the shipped class
# filter — and the lower pane is about ONE level. Swapping them here is the
# sabotage BQ51's *descended* leg exists to catch; its ROOT leg would stay right,
# which is why the check names a descended node.
# --- §F item F6 (issue 0308): THE PANE READS THE ROW'S OWN DATABASE ----------
#
# `d:<registry idx>` when row `id` belongs to a FOREIGN database, `{}` when it
# belongs to the current one. PURE apart from the snapshot read.
#
# ⚠ AN All-DBs HEADER DOES NOT MAKE THE CURRENT DATABASE FOREIGN. Two-pane item
# 15 keeps the current DB's ROWS unprefixed even under its own header (the
# prefix would be a registry index, which moves when a raw is closed, and every
# persisted id would then name a row that no longer exists), so this branch is
# belt-and-braces rather than reachable today — and it is spelled anyway,
# because the alternative failure is the pane answering NOTHING for the database
# the user is actually looking at.
proc wviewer::browser_row_foreign {token id} {
  variable browsercurdb
  set n [wviewer::browser_row_db $id]
  if {$n eq {}} { return {} }
  if {[info exists browsercurdb($token)] && \
      [wviewer::dget $browsercurdb($token) id {}] eq "d:$n"} { return {} }
  return "d:$n"
}

# The ENTRY LIST the lower pane must draw row `id` from: the current database's
# bar-matched, class-filtered snapshot for a current-DB row, that FOREIGN
# database's own for a foreign one.
#
# ⚠⚠ A FOREIGN SLOT THIS SNAPSHOT DOES NOT CARRY ANSWERS `{}` — AN EMPTY PANE —
# AND NEVER THE CURRENT DATABASE'S ENTRIES. That is issue 0308's whole lesson
# read in the right direction: the shipped code fell back to the current
# inventory and the pane then listed the current run's namesakes under a foreign
# node, with nothing on screen to say so. Nothing is a state the caption can
# describe truthfully; someone else's signals is not.
proc wviewer::browser_sea_ent {token id} {
  variable browserseaent
  variable browserseadbent
  set slot [wviewer::browser_row_foreign $token $id]
  if {$slot eq {}} {
    if {![info exists browserseaent($token)]} { return {} }
    return $browserseaent($token)
  }
  if {![info exists browserseadbent($token)]} { return {} }
  set m $browserseadbent($token)
  if {![dict exists $m $slot]} { return {} }
  return [dict get $m $slot]
}

# The tree row the pane's cells were LAST DRAWN FOR, or {}. The pane's two
# per-database consumers (the Plot's raw hint, the Descend-to's split grammar)
# read the database out of THIS rather than re-reading the treeview selection,
# because the selection can have moved since the draw and a gesture must act on
# the cells the user can see.
proc wviewer::browser_sea_row {token} {
  variable browserseadbid
  if {![info exists browserseadbid($token)]} { return {} }
  return $browserseadbid($token)
}

# `keepnote 1` says THIS REFRESH IS NOT A NAVIGATION — see the clear below and
# the `<Configure>` trampoline. The default is the navigation.
proc wviewer::browser_sea_refresh {token {keepnote 0}} {
  variable windows
  variable browsersea
  variable browserseaent
  variable browserseadbid
  variable browserseasel
  variable browserseaanchor
  variable browserseanote
  # §F item F5: THE NOTICE IS CLEARED BY THE NEXT REFRESH, and this line is
  # where its whole lifetime is decided. A refresh means the user moved — a new
  # node, a new keystroke, a re-scoped tree — and a sentence about the PREVIOUS
  # gesture's refusal would then be a caption on a pane it does not describe.
  # It is cleared BEFORE the draw below, so this refresh's own pane draws clean;
  # `browser_notice` sets it and redraws afterwards.
  #
  # ⚠⚠ ISSUE 0318: "A REFRESH MEANS THE USER MOVED" IS TRUE OF EVERY CALLER BUT
  # ONE. The sea canvas's `<Configure>` arrives here too, and a resize is not a
  # move — the user changed how wide the pane is and asked for nothing — so the
  # paragraph above was clearing a sentence off a pane it still described, and
  # dragging issue 0312's grip narrow left the unexplained empty box behind.
  # `keepnote` is that one caller saying which it is. THE DEFAULT IS 0, i.e.
  # NAVIGATION, deliberately: a new caller that forgets to classify itself
  # clears, which is the safe direction, since a stale reason is worse than no
  # reason. The count of callers is pinned by BZ02 — by SOURCE COUNT, which is
  # what that check can do: a caller spelled with another variable name is
  # invisible to it, so classify a new one HERE rather than trusting the ledger.
  #
  # ⚠ NORMALISED RATHER THAN USED RAW, and that is this proc's own contract: the
  # header above promises every rung is a guard because it rides
  # <<TreeviewSelect>>, where a throw pops a MODAL bgerror that hangs a headless
  # run — and `if {!$junk}` throws. Anything Tcl does not read as a TRUE boolean
  # therefore reads as 0, which is both no-throw and the safe direction. (It is
  # `Tcl_GetBoolean` semantics, so any non-zero integer is a yes — there is no
  # such caller, and a future one saying `2` means the same as `1`.)
  set keepnote [expr {[string is true -strict $keepnote] ? 1 : 0}]
  if {!$keepnote} { set browserseanote($token) {} }
  # WHAT A KEPT NOTICE IS, read once: the tail must not re-caption the pane out
  # from under it. {} on every navigation, and on a geometry event that has no
  # notice to keep.
  set kept {}
  if {$keepnote && [info exists browserseanote($token)]} {
    set kept $browserseanote($token)
  }
  if {![dict exists $windows $token]} { return 0 }
  set c [wviewer::browser_sea_canvas $token]
  if {$c eq {}} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  set sel {}
  catch {set sel [$tv selection]}
  # R4 keeps this to one id; a legacy multi-selection resolves to its first,
  # which is browser_populate's own narrowing rule spelled the same way.
  set id [lindex $sel 0]
  if {![info exists browserseaent($token)]} { set browserseaent($token) {} }
  # §F item F6: THE ROW THE PANE IS ABOUT, RECORDED BEFORE ANYTHING IS DRAWN.
  # One write, and the pane's gestures project the database out of it — see
  # `browser_sea_row`.
  set browserseadbid($token) $id
  # ⚠⚠ AND THE ENTRIES COME FROM THE ROW'S OWN DATABASE (issue 0308). This used
  # to be `browserseaent($token)` unconditionally, which is the current
  # database's list — so a `d:N|` row's path was stripped of the very prefix
  # that said where to look it up and was then looked up in the only inventory
  # there was. Where the two databases had no name in common that showed as an
  # empty pane under a false caption; where they collided it showed as the
  # CURRENT run's signals listed under a foreign node.
  set ent [wviewer::browser_sea_ent $token $id]
  set pairs {}
  set own 0
  if {$id eq {}} {
    # no selection at all: R4 says this cannot happen with a design root in the
    # tree, and BP43a is the tombstone for the All-DBs case where it can. An
    # EMPTY pane with a named reason beats a stale one.
    set path {}
    set nostate 1
  } else {
    set nostate 0
    set path [wviewer::browser_id_path $id]
    if {[catch {wviewer::browser_level_names $ent $path} nms]} { set nms {} }
    # RULING F4 + §F item F6: THE ROW'S OWN database's kind, not the current
    # one's. `$ent` is now that row's inventory, so classifying it with the
    # current kind would declass a foreign VCD's `m.sub.sig` down to `sub` with
    # an analog raw current — the very defect RULING F4 removed one surface over.
    set seatype [wviewer::browser_id_type $token $id]
    foreach nm $nms {
      set e {}
      if {[catch {wviewer::signal_entry $nm $seatype} e]} { continue }
      lappend pairs [list [wviewer::browser_label $e] \
                          [wviewer::browser_label_full $e]]
    }
    set own [wviewer::browser_sea_own $token $path $id]
  }
  set browsersea($token) $pairs
  set browserseasel($token) {}
  set browserseaanchor($token) 0
  set n [wviewer::browser_sea_draw $token]
  # ⚠⚠ AND A KEPT NOTICE KEEPS THE CAPTION TOO (issue 0318). `browser_notice`
  # writes its sentence to the very label the arms below write, so re-captioning
  # here would put the shipped §7.2 sentence back under a pane that is still
  # DRAWING the notice — two surfaces disagreeing about one empty pane, which is
  # the drift F5 exists to remove. It also matters on the pane that is NOT empty:
  # there the canvas arm is silent by construction and the caption is the only
  # surface carrying the reason. A geometry event re-flows the pane; it says
  # nothing. The draw is ABOVE this line, so the sentence has already been
  # re-wrapped to the new width — that is what makes it a redraw and not a
  # survivor.
  if {$kept ne {}} { return $n }
  # §7.2's three distinguishable states, plus the ordinary count. SPELLED IN
  # browser_msg AND NOWHERE ELSE — three sentences written inline here would be
  # three sentences to keep in step with the spec.
  if {$nostate} {
    wviewer::browser_sea_say $token seanone
  } elseif {$own == 0} {
    wviewer::browser_sea_say $token seaempty \
      [wviewer::browser_sea_label $token $path $id]
  } elseif {$n == 0 && [wviewer::browser_bars_active $token]} {
    wviewer::browser_sea_say $token seabars 0 $own
  } elseif {$n == 0} {
    wviewer::browser_sea_say $token seaclass 0 $own
  } else {
    wviewer::browser_sea_say $token seacount $n $own
  }
  return $n
}

# The node's OWN-LEVEL signal count BEFORE either narrowing — the `<own>`
# denominator §7.2's line needs, and the ONE fact that tells "this node has no
# signals of its own" (a pure ancestor: MEASURED, 12 of tb_bandgap's 44 kept
# nodes) apart from "everything at this level was hidden".
#
# ⚠ IT COUNTS THE UNFILTERED INVENTORY, and that is what makes §7.2's THIRD
# state expressible at all: with `Show device internals` off, a node whose own
# level is all-device has own > 0 and shown == 0, which is a different sentence
# from own == 0. Counting the filtered set would collapse the two.
# ⚠ `id` (§F item F6, issue 0308) NAMES THE ROW, AND THEREFORE THE DATABASE, THE
# COUNT IS ABOUT. It is OPTIONAL and defaults to the current database, so every
# pre-F6 caller and the whole shipped `BQ`/`FD4x` band keeps its exact meaning by
# construction. Told a foreign row it counts THAT database's UNFILTERED
# inventory: this number is the denominator of §7.2's caption, and counting the
# current run's names under a foreign node is how the pane came to say
# "'m.sub' has no signals of its own" about a scope with six (issue 0308) — and,
# where the two runs collide, "1 of 1 signals" about the wrong one.
#
# ⚠ A FOREIGN SLOT THE SNAPSHOT DOES NOT CARRY COUNTS 0, never the current
# database's total. `browser_sea_ent` degrades the same way and for the same
# reason, and the two must agree or the caption would deny what the pane draws.
proc wviewer::browser_sea_own {token path {id {}}} {
  variable browsersigs
  variable browserdbsigs
  set slot [wviewer::browser_row_foreign $token $id]
  if {$slot eq {}} {
    if {![info exists browsersigs($token)]} { return 0 }
    set names $browsersigs($token)
  } else {
    set names {}
    if {[info exists browserdbsigs($token)]} {
      foreach db $browserdbsigs($token) {
        if {[wviewer::dget $db id {}] eq $slot} {
          set names [wviewer::dget $db names {}]
          break
        }
      }
    }
  }
  # RULING F4: the row's database's kind, or the own-level count of a digital
  # scope would be taken against a declassed path and answer 0 -- which
  # `browser_sea_refresh` renders as "has no signals of its own".
  #
  # ⚠ AND THE SAME CASE RULE `browser_level_names` CARRIES, for the same reason
  # and it must not drift from it: this count is the DENOMINATOR of the caption
  # over the very list that proc selects. Folding case on a digital scope counted
  # a sibling scope's wires -- MEASURED, `top.mod` and `top.MOD` each answered 2
  # of the 2 names in the inventory, so the pane said `2 of 2 signals` about a
  # scope that owns one.
  set owntype [wviewer::browser_id_type $token $id]
  set n 0
  foreach nm $names {
    set e {}
    if {[catch {wviewer::signal_entry $nm $owntype} e]} { continue }
    set p [wviewer::dget $e path {}]
    if {[wviewer::dget $e class {}] eq {digital}} {
      if {$p eq $path} { incr n }
    } elseif {[string equal -nocase $p $path]} {
      incr n
    }
  }
  return $n
}

# The name §7.2's first state puts in front of `has no signals of its own`: the
# dotted path, or the design's own name at the root (`has no signals of its own`
# about an empty string reads as a bug report).
#
# ⚠ `id` (§F item F6) IS WHICH ROOT. Every design root decodes to the SAME empty
# path — `g:` and `d:1|g:` alike — so without the row this proc named the CURRENT
# design under a FOREIGN database's root, i.e. it put one run's name on another
# run's empty pane. Optional and defaulting to the current database, so every
# pre-F6 caller reads exactly as it did.
proc wviewer::browser_sea_label {token path {id {}}} {
  variable browserraw
  variable browserdbsigs
  if {$path ne {}} { return $path }
  set slot [wviewer::browser_row_foreign $token $id]
  if {$slot ne {}} {
    if {[info exists browserdbsigs($token)]} {
      foreach db $browserdbsigs($token) {
        if {[wviewer::dget $db id {}] eq $slot} {
          return [wviewer::browser_root_label [wviewer::dget $db path {}]]
        }
      }
    }
    # a foreign slot the snapshot has lost: `design`, the same floor
    # browser_root_label gives an empty path, never the current design's name.
    return [wviewer::browser_root_label {}]
  }
  set rp {}
  if {[info exists browserraw($token)]} { set rp $browserraw($token) }
  return [wviewer::browser_root_label $rp]
}

# §7.2 SAID, on the lower pane's OWN caption. Returns the result list.
#
# ⚠⚠ IT WRITES `$f.pw.sea.st`, NOT THE SIDEBAR'S STATUS LINE, AND THE CHOICE WAS
# FORCED BY MEASUREMENT (receipt §"the status line"). Item 9's `.ph` carries
# `<matched> of <total> signals` about the WHOLE INVENTORY; §7.2's sentence is
# about the SELECTED NODE. They are two facts, and the three ways of putting
# them on one label were each measured against the suites:
#   * REPLACE  — BT24/BT25/BT26/BT27's counts, BD52/BD52b's byte-identity and
#     BW46's "the search really RAN" proof all move, and the FILTER and AND bar
#     states stop being distinguishable at the design root (both read `0 of N`),
#     which is the discriminator item 10 rebuilt twice to keep.
#   * APPEND a third line — BD52/BD52b plus BX37/BX42/BX44/BX45/BX46 and
#     BH50/BH51/BH54 all assert `[$F.ph cget -text]` BYTE-IDENTICALLY as
#     "Signal Browser\n<msg>"; a third line reds every one of them.
#   * A CAPTION ON THE PANE IT DESCRIBES — costs exactly one existing check (the
#     sea frame's pinned child set) and reads better, because the sentence sits
#     under the list it is about.
# The third was taken. `browser_say` is untouched; only the SPELLING is shared,
# in browser_msg, which is what the plan asked for.
#
# NO ECHO, and that is deliberate rather than an omission: this fires on every
# keystroke and every arrow-key move through the tree, and `wviewer::echo`
# writes an action-log `-result` line. browser_say echoes because it reports a
# USER-INITIATED sync; this reports a cursor moving.
proc wviewer::browser_sea_say {token kind {a {}} {b {}}} {
  variable windows
  switch -- $kind {
    seanone  { set r [list seanone] }
    seaempty { set r [list seaempty $a] }
    seabars  { set r [list seabars $a $b] }
    seaclass { set r [list seaclass $a $b] }
    default  { set r [list seacount $a $b] }
  }
  set m [wviewer::browser_msg $r]
  if {[dict exists $windows $token]} {
    set l [dict get $windows $token top].wvbrowser.pw.sea.st
    if {![catch {winfo exists $l} e] && $e} { catch {$l configure -text $m} }
  }
  return $r
}

# --- §F item F5: THE EMPTY-PANE NOTICE ----------------------------------------
#
# One sentence, on every surface that can carry it, about why the lower pane has
# nothing the user asked for. Returns 1 when it reached at least one surface.
#
# ⚠⚠ IT IS A RENDERER, NOT AN AUTHOR. The sentence arrives already written —
# `ase::browser_digital_msg` prefixes the F2 resolver's own refusal sentence and
# adds nothing (RULING 5f-3: "F5 renders this sentence rather than composing its
# own, so the two cannot drift"). Nothing in this proc may inspect it, shorten
# it, or decide a different one; that is why it takes a string and not a cause
# code. The three causes F5's spec row distinguishes — no VCD loaded at all, the
# run traced nothing, and no mapping from this instance to a scope — are three
# different sentences minted where each is DECIDED, in src/ase.tcl.
#
# ⚠ THREE SURFACES, DELIBERATELY, because the pane is not always the empty one.
# When the caller has fallen through to the analog path the tree has just landed
# on a real node whose pane is full, so the canvas arm of browser_sea_draw stays
# silent by construction and the caption plus the sidebar status line are what
# carry the reason. When nothing was shown at all, the canvas carries it too.
#
# ⚠ NO ECHO HERE. The caller owns the CIW line (`ase::echo … error`, §F's F5
# row) — echoing again would put the same sentence in the action log twice, and
# browser_say's own echo has already reported what the fall-through DID show.
proc wviewer::browser_notice {token msg} {
  variable windows
  variable browserseanote
  if {$msg eq {}} { return 0 }
  set browserseanote($token) $msg
  if {![dict exists $windows $token]} { return 0 }
  set ok 0
  set f [dict get $windows $token top].wvbrowser
  set l $f.pw.sea.st
  if {![catch {winfo exists $l} e] && $e} {
    if {![catch {$l configure -text $msg}]} { set ok 1 }
  }
  if {[wviewer::browser_status $token $msg]} { set ok 1 }
  # the canvas arm: it draws the notice only on a pane with no cells, and it is
  # called unconditionally so that "is the pane empty?" is asked in exactly one
  # place (browser_sea_draw) rather than answered twice from two sides.
  catch {wviewer::browser_sea_draw $token}
  return $ok
}

# §F item F5, second half (RULING F1e): 1 when this viewer's lower pane is
# listing NOTHING AT ALL, 0 whenever that cannot be established.
#
# ⚠⚠ IT ANSWERS 0 WHEN IT DOES NOT KNOW, AND THAT ASYMMETRY IS THE POINT. Its
# one caller writes a NOTICE on a 1, so a "yes" guessed from a viewer that has
# no window, or a pane state that has never been built, would put a sentence
# about an empty pane on a pane nobody has drawn — the exact drift F5 exists to
# prevent. A missing window and a missing pane state are therefore both `0`
# ("no claim"), not `1` ("nothing to show").
#
# ⚠⚠ IT ASKS BOTH HALVES OF THE QUESTION, AND THE SECOND HALF IS WHAT MAKES IT
# TRUE (salvage pass, review finding R2-D). `browsersea` is the pane's own
# model, but it is the FILTERED set — the pairs actually drawn — so an empty
# `browsersea` has TWO causes: a node with no own-level names at all, and a node
# whose names were every one of them hidden by a Search/Filter bar or a class
# filter. Answering 1 for the second was a guessed yes about a node that has
# signals, and it made the one caller replace the shipped, TRUE caption
# "0 of 2 signals (the Search/Filter bar is hiding them)" with a sentence
# claiming the pane lists nothing because the database is foreign. MEASURED:
# same node read twice, bar off -> drawn 2 / own 2, bar on -> drawn 0 / own 2,
# and the old body called the second one empty.
#
# So the prior question is asked explicitly: `browser_sea_own` counts the
# UNFILTERED inventory at this node's level (its own comment says so, and says
# why counting the filtered set collapses the two states). Nothing drawn AND
# nothing to draw is the one state `browser_sea_refresh` captions with the
# `seaempty` arm — which is precisely the caption RULING F1e's arm exists to
# correct — so this reader and that arm now agree by construction rather than
# by coincidence.
#
# ⚠ THE SELECTION IS RE-DERIVED HERE rather than cached by the refresh, so the
# reader stays total and stateless: a token whose pane has never been refreshed
# has nothing to go stale, and there is no new per-token array for
# `browser_forget` to have to remember to unset.
proc wviewer::browser_sea_empty {token} {
  variable windows
  variable browsersea
  if {![dict exists $windows $token]} { return 0 }
  if {![info exists browsersea($token)]} { return 0 }
  if {[llength $browsersea($token)]} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return 0 }
  set sel {}
  catch {set sel [$tv selection]}
  set id [lindex $sel 0]
  # no selection at all is `seanone`, not `seaempty`: no node is being shown, so
  # there is no pane to make a claim about.
  if {$id eq {}} { return 0 }
  set path {}
  if {[catch {wviewer::browser_id_path $id} path]} { return 0 }
  set own 0
  # §F item F6: the count is asked OF THAT ROW'S DATABASE. Without the row this
  # reader answered "the pane lists nothing" for every foreign node whose path
  # the current database happens not to carry — which was true of the pane and
  # false of the node, and it is what made RULING F1e's notice fire on scopes
  # that have signals.
  if {[catch {wviewer::browser_sea_own $token $path $id} own]} { return 0 }
  return [expr {$own == 0 ? 1 : 0}]
}

# --- the six gestures (spec §5.3) ---------------------------------------------
# ⚠ EVERY ONE OF THEM RIDES A Tk BINDING, so every one of them is TOTAL: a throw
# in a binding pops bgerror, modal under X. `browser_menu_post`'s rule verbatim.

# Canvas pixel -> item index, or -1 for a MISS. `canvasx`/`canvasy` first,
# because the pane SCROLLS horizontally and a widget-relative x is not a
# content-relative one the moment the user has scrolled.
proc wviewer::browser_sea_hit {token W x y} {
  set c [wviewer::browser_sea_canvas $token]
  if {$c eq {} || $W ne $c} { return -1 }
  set cx $x ; set cy $y
  catch {set cx [$c canvasx $x]}
  catch {set cy [$c canvasy $y]}
  lassign [wviewer::browser_sea_layout $token] per cols colw rowh n paneh
  if {!$n} { return -1 }
  set r -1
  catch {set r [wviewer::browser_flow_hit $cx $cy $per $colw $rowh $n]}
  return $r
}

# LMB: select one, REPLACING the set. A miss clears it — clicking the empty
# gutter is how a user says "never mind", and leaving the old set selected there
# is what makes the next Plot surprising.
proc wviewer::browser_sea_click {token W x y} {
  catch {focus $W}
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {$i < 0} { return [wviewer::browser_sea_select $token {} 0] }
  return [wviewer::browser_sea_select $token [list $i] $i]
}

# Shift-LMB: extend from the anchor in FLOW ORDER — down the column, then to the
# next — which is what the arithmetic range between two indices already means,
# because the flow IS column-major (browser_flow_cell). A visual rectangle would
# be a different gesture and is not what spec §5.3 asks for.
proc wviewer::browser_sea_extend {token W x y} {
  variable browserseaanchor
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {$i < 0} { return [llength [wviewer::browser_sea_selection $token]] }
  set a 0
  if {[info exists browserseaanchor($token)]} { set a $browserseaanchor($token) }
  if {![string is integer -strict $a]} { set a 0 }
  set lo [expr {$a < $i ? $a : $i}]
  set hi [expr {$a < $i ? $i : $a}]
  set out {}
  for {set k $lo} {$k <= $hi} {incr k} { lappend out $k }
  # the anchor DOES NOT MOVE — a second Shift-click must re-extend from the same
  # origin, which is the whole point of an anchor.
  return [wviewer::browser_sea_select $token $out]
}

# Ctrl-LMB: toggle one, KEEPING the set. The toggled cell becomes the anchor,
# matching every list widget in the toolkit.
proc wviewer::browser_sea_toggle {token W x y} {
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {$i < 0} { return [llength [wviewer::browser_sea_selection $token]] }
  set cur [wviewer::browser_sea_selection $token]
  set at [lsearch -exact $cur $i]
  if {$at >= 0} { set cur [lreplace $cur $at $at] } else { lappend cur $i }
  return [wviewer::browser_sea_select $token $cur $i]
}

# Indices -> plot. The ONE route every sea plot gesture converges on, and it
# goes through `plot_signals` exactly as browser_plot_ids does, so item 7's
# destination policy is read in ONE place for BOTH panes.
proc wviewer::browser_sea_plot_idx {token idxs {destover {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set names {}
  foreach i $idxs {
    set n [wviewer::browser_sea_name $token $i]
    if {$n ne {} && [lsearch -exact $names $n] < 0} { lappend names $n }
  }
  if {![llength $names]} {
    wviewer::echo {signal browser: nothing selected to plot} error
    return 0
  }
  # ⚠⚠ §F item F6: THE PANE'S DATABASE RIDES ALONG, exactly as the tree's plot
  # route already sends `browser_leaf_specs`' db half (spec §D1 / DEFECT 2).
  # Before F6 this pane could only ever hold the CURRENT database's names, so an
  # unarmed plot resolved them against the current raw and was right by
  # construction. It can now hold a foreign database's names — and an unarmed
  # plot resolves by NAME through `resolve_signal_db`, whose documented tie-break
  # is THE CURRENT DATABASE WINS (`signal_list_all` yields the current DB first
  # and that proc returns the first hit — see its own ⚠ at :2364, and `db_by_
  # index`'s, which exists for exactly this reason). So an unarmed plot of a
  # foreign `x1.sig` that the current run also carries would silently draw the
  # CURRENT run's namesake, which is issue 0308's wrong answer one gesture on.
  # One row, one database, so one index repeated is the whole hint.
  wviewer::plot_dbs_arm $token \
    [lrepeat [llength $names] [wviewer::browser_row_db [wviewer::browser_sea_row $token]]]
  set errs {}
  set rc [catch {wviewer::plot_signals $token $names {} $destover} errs]
  wviewer::plot_dbs_take $token          ;# no-op after a real call; clears after a stub
  if {$rc} {
    wviewer::echo "signal browser: $errs" error
    return 0
  }
  foreach e $errs {
    wviewer::echo "signal browser: [lindex $e 0]: [lindex $e 1]" error
  }
  return [llength $names]
}

# Double-LMB and MMB. SELECTION-INDEPENDENT in exactly browser_plot_at's way:
# the cell comes from the POINTER, and when that cell is in the selection the
# WHOLE selection plots. `event generate` does not reliably set a selection
# first, so a handler that read only the selection would be untestable AND would
# surprise a user who double-clicked a cell other than the selected one.
proc wviewer::browser_sea_plot_at {token W x y} {
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {$i < 0} { return 0 }
  set sel [wviewer::browser_sea_selection $token]
  if {[lsearch -exact $sel $i] >= 0} { set idxs $sel } else { set idxs [list $i] }
  return [wviewer::browser_sea_plot_idx $token $idxs]
}

# <Configure>: the pane was resized (the sash moved — which is the whole point
# of R3), so re-flow. It re-reads the tree selection through the ordinary
# refresh rather than carrying a second draw path, because a second path is how
# the two get to disagree about what is selected.
# ⚠⚠ AND IT IS THE ONE CALLER THAT IS NOT A NAVIGATION (issue 0318). Everything
# that reaches this proc is GEOMETRY — issue 0312's width grip, the sash, the
# toplevel resized, a tab bar appearing, a window manager tiling the window — and
# in every one of them the user asked for nothing: which NAMES the pane lists has
# not changed, only how wide it is. So the `1` below is not an optimisation, it is
# the whole fix: without it the refresh cleared §F item F5's in-pane sentence and
# a sidebar dragged narrow lost the only thing on screen saying why its lower
# pane was empty.
#
# ⚠ TWO THINGS THIS DOES **NOT** COVER, DECLARED RATHER THAN IMPLIED (both are
# adversarial-review findings on the 0318 fix):
#   * THE PANE'S SELECTION IS STILL DROPPED by the refresh below
#     (`browserseasel`/`browserseaanchor` are reset unconditionally), so a resize
#     silently discards what the user picked in the lower pane. Same door, second
#     casualty, and it needs its own ruling about an INDEX-based selection —
#     filed as ISSUE 0320, deliberately not widened into 0318.
#   * `Ctrl-B` TWICE still clears the notice, and that is not this trampoline:
#     hiding and re-showing the sidebar goes through `browser_show`, whose own
#     rule is SHOW = REPOPULATE (it re-reads the raw), so it is a navigation by
#     the code's own declaration and clears at the top of the refresh.
#
# ⚠ ONE ARGUMENT ON THE ONE TRAMPOLINE, rather than a save-and-restore around the
# call, and the reason is the ORDER inside the refresh: the clear happens BEFORE
# the draw, so a restore afterwards would have to draw a second time to put the
# sentence back — and it would still have let the pane's caption be overwritten
# in between. It is also NOT a private `browser_sea_draw` here: the paragraph
# above is still true, a geometry event must re-read the tree selection through
# the one refresh rather than grow a second draw path that can disagree with it.
proc wviewer::browser_sea_configure {token} {
  return [wviewer::browser_sea_refresh $token 1]
}

# --- the sea's RMB menu — A DISTINCT WIDGET ----------------------------------
# ⚠⚠ `wvseamenu`, NEVER `wvbrowsermenu`, and the reason is not tidiness.
# ctx_menu_widget DESTROYS and re-mints the widget it is asked for, so posting
# the sea's menu through the tree's name would tear down the tree's menu
# mid-life, and `ctx_menu_drop` on either name would take the other down. The
# two panes hold two independent selections and each menu's -commands close over
# ITS pane's currency (row ids one side, flow indices the other); sharing one
# widget aliases them. It also disturbs the tree menu's reserved index 7, which
# BM02 and BH40 pin.
#
# THE ENTRY TABLE IS DELIBERATELY IDENTICAL to browser_menu_build's — same
# eight entries in the same order, so BM23's index table describes both panes.
# It is spelled twice rather than factored into a shared builder because
# BM01-BM09 grep browser_menu_build's own body; the AGREEMENT is pinned
# behaviourally instead, by comparing the two posted menus entry for entry.

# THE GATE: the flow indices an RMB at canvas pixel (x,y) acts on, or {}.
# browser_menu_ids' rule verbatim: the clicked cell when it is not in the
# selection, the WHOLE selection when it is; a miss posts NOTHING; and it NEVER
# MUTATES the selection.
proc wviewer::browser_sea_menu_ids {token W x y} {
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {$i < 0} { return {} }
  set sel [wviewer::browser_sea_selection $token]
  if {[lsearch -exact $sel $i] >= 0} { return $sel }
  return [list $i]
}

# Flow indices -> {ok <dotted path>} / {err <message>}. The sea's twin of
# browser_target_path, resolved through the NAME (`sig_split`'s declassed path),
# which is the same expression browser_target_path uses for a leaf row.
#
# ⚠ THE MULTI-CELL RULE IS browser_target_path's, VERBATIM: a set resolves only
# when every cell yields the SAME path, and a disagreeing set is an `err` that
# leaves the menu entry DISABLED. Silent first-wins is the ruling-17 defect.
proc wviewer::browser_sea_target_path {token idxs} {
  if {![llength $idxs]} {
    return [list err {select a signal in the Signal Browser first}]
  }
  # ⚠ RULING F4: the pane's DATABASE's kind. A one-argument split declassed a
  # digital name, so on a VCD whose top `$scope` is one letter this answered a
  # path with that level DELETED, the menu entry was built ENABLED against it,
  # and the descend then found no such node and returned silently. MEASURED on
  # `m.sub.sig`: `ok sub`, for a tree whose group is `g:m.sub`.
  #
  # ⚠⚠ AND IT IS THE PANE'S ROW, NOT `browser_curtype`, SINCE §F item F6. Until
  # F6 the two were the same fact — the pane drew the current database's entries
  # and only those — and the comment here said so. The pane now draws whichever
  # database the selected ROW belongs to, so reading the current kind would split
  # a foreign VCD's name with ngspice's grammar the moment an analog raw is
  # current, which is exactly the defect this proc was fixed for, one database
  # over. `browser_sea_row` is {} for a pane drawn from the current DB, and
  # `browser_id_type` maps that back to the current kind — so every pre-F6 state
  # answers identically.
  set seatype [wviewer::browser_id_type $token [wviewer::browser_sea_row $token]]
  set path {}
  set first 1
  foreach i $idxs {
    set nm [wviewer::browser_sea_name $token $i]
    if {$nm eq {}} { return [list err "unknown signal '$i'"] }
    set p [lindex [wviewer::sig_split $nm $seatype] 0]
    if {$first} { set path $p ; set first 0 } \
    elseif {$p ne $path} {
      return [list err {those signals are in different parts of the hierarchy}]
    }
  }
  return [list ok $path]
}

# THE TREE ROOT THE PANE'S OWN WALK STARTS FROM: the design root of the database
# the pane's ROW belongs to, `browser_root_id`'s answer for a current-DB pane.
#
# ⚠⚠ §F item F6, SECOND HALF (the reviewer's finding on item 7's first landing).
# F6 made `browser_sea_target_path` answer in the row's own database and then
# handed that answer to a walk that started at `browser_root_id $rows` — which is
# hard-wired to the CURRENT database's root (`g:`, or `d:0|g:` under All-DBs).
# So the database identity F6 rescued was thrown away one proc later, and the
# `Descend to here` entry — now ENABLED on a foreign pane, where it used to be
# disabled — either said `'TOP.dcell' is not in the Signal Browser tree` about a
# row that IS in the tree (`d:1|g:TOP.dcell`), or, where the two databases
# collide, resolved to the CURRENT database's namesake row with no cue at all.
# MEASURED, both. That is the same wrong-answer shape this item was written to
# remove, so the walk starts where the row lives.
#
# ⚠ A SLOT WHOSE ROOT ROW IS NOT IN `$rows` STILL ANSWERS `d:N|g:` AND NOT `{}`,
# deliberately: `{}` is browser_node_for's TOP LEVEL, i.e. the current database's
# unprefixed rows, which is precisely the fallback that made the defect. With no
# such root row nothing has it as a parent, the walk matches nothing, and the
# caller's "not in the Signal Browser tree" sentence is then TRUE.
proc wviewer::browser_sea_root_id {token rows} {
  set slot [wviewer::browser_row_foreign $token [wviewer::browser_sea_row $token]]
  if {$slot eq {}} { return [wviewer::browser_root_id $rows] }
  return "$slot|g:"
}

proc wviewer::browser_sea_descend_to {token idxs} {
  set r [wviewer::browser_sea_target_path $token $idxs]
  if {[lindex $r 0] ne {ok}} {
    catch {wviewer::browser_status $token [lindex $r 1]}
    return 0
  }
  # ⚠ IT RE-ENTERS THE TREE'S OWN COMMAND rather than re-implementing the walk:
  # browser_descend_to is 80 lines of context loan, rollback and re-read, and a
  # second copy of it would drift on the first fix. The tree row for this path
  # is what it wants, and browser_node_for is the decoder.
  variable browserrows
  set rows {}
  if {[info exists browserrows($token)]} { set rows $browserrows($token) }
  set segs [wviewer::hier_split [lindex $r 1]]
  # ⚠⚠ THE ROW'S OWN DATABASE'S ROOT (§F item F6) — see browser_sea_root_id.
  # `browser_root_id $rows` here was the current database's root whatever pane
  # the gesture came out of, which is the defect that proc's header records.
  lassign [wviewer::browser_node_for $rows $segs \
             [wviewer::browser_sea_root_id $token $rows]] id matched
  # ⚠ AN UNREACHABLE NODE IS SAID, NEVER SWALLOWED. This arm used to `return 0`
  # in silence, so the entry above — which is built ENABLED on `ok` alone — did
  # nothing at all and explained nothing. A resolved path with no row is a real
  # state a bar can produce (a Filter that hides the scope), so it needs a
  # sentence rather than a stricter gate. A literal string and not a
  # `browser_msg` kind: that proc's arms are the SCOPE-CHANGE vocabulary and its
  # return count is pinned as a ledger.
  if {$id eq {}} {
    catch {wviewer::browser_status $token \
             "'[lindex $r 1]' is not in the Signal Browser tree"}
    return 0
  }
  return [wviewer::browser_descend_to $token [list $id]]
}

proc wviewer::browser_sea_copy_names {token idxs} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set names {}
  foreach i $idxs {
    set n [wviewer::browser_sea_name $token $i]
    if {$n ne {} && [lsearch -exact $names $n] < 0} { lappend names $n }
  }
  if {![llength $names]} { return 0 }
  set top [dict get $windows $token top]
  # ⚠ `::clipboard` FULLY QUALIFIED — this namespace has its own zero-argument
  # `wviewer::clipboard` and an unqualified call resolves to THAT, throws, and
  # is swallowed (item 10's measured defect, BM33).
  if {[catch {
    ::clipboard clear -displayof $top
    ::clipboard append -displayof $top [join $names "\n"]
  }]} { return 0 }
  set n [llength $names]
  catch {wviewer::browser_status $token \
           "copied $n name[expr {$n == 1 ? {} : {s}}]"}
  return $n
}

proc wviewer::browser_sea_send_to_add_trace {token idxs} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set names {}
  foreach i $idxs {
    set n [wviewer::browser_sea_name $token $i]
    if {$n ne {} && [lsearch -exact $names $n] < 0} { lappend names $n }
  }
  if {![llength $names]} { return 0 }
  set w {}
  if {[catch {wviewer::add_trace_dialog $token} w]} { return 0 }
  if {$w eq {}} { return 0 }
  if {[catch {winfo exists $w.expr} e] || !$e} { return 0 }
  catch {
    $w.expr delete 0 end
    $w.expr insert end [lindex $names 0]
    focus $w.expr
  }
  # ⚠⚠ §F item F6: AND THE ROW'S DATABASE GOES WITH THE NAME, exactly as the
  # sibling `Plot` entry arms `plot_dbs_arm`. Before F6 this pane could only hold
  # the CURRENT database's names, so handing a bare name onward was right by
  # construction; it can hold a FOREIGN database's names now, and `add_trace`'s
  # name search resolves a collision to the CURRENT database (`resolve_signal_db`
  # walks `signal_list_all`, which yields the current DB first). Two entries in
  # ONE menu landing on two different runs, with no cue, is the very shape this
  # item exists to remove. `browser_row_db` is {} for a current-DB pane, which
  # `atd_db_arm` reads as "no arm" — so every pre-F6 state is untouched.
  wviewer::atd_db_arm $token [lindex $names 0] \
    [wviewer::browser_row_db [wviewer::browser_sea_row $token]]
  return 1
}

proc wviewer::browser_sea_menu_build {token idxs} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set names {}
  foreach i $idxs {
    set nm [wviewer::browser_sea_name $token $i]
    if {$nm ne {} && [lsearch -exact $names $nm] < 0} { lappend names $nm }
  }
  if {![llength $names]} { return {} }
  set m [wviewer::ctx_menu_widget $token wvseamenu]
  if {$m eq {}} { return {} }
  set n [llength $names]
  $m add command -state disabled \
    -label [expr {$n == 1 ? [lindex $names 0] : "$n signals"}]
  $m add separator
  $m add command \
    -label "Plot ([wviewer::dest_menu_label $token [wviewer::plot_dest $token]])" \
    -command [list wviewer::browser_sea_plot_idx $token $idxs]
  set sub [wviewer::ctx_menu_child $m dest]
  if {$sub ne {}} {
    foreach lab [wviewer::dest_labels] {
      set code [wviewer::dest_norm $lab]
      $sub add command -label [wviewer::dest_menu_label $token $code] \
        -command [list wviewer::browser_sea_plot_idx $token $idxs $code]
    }
  }
  $m add cascade -label {Plot to} -menu $sub
  $m add command -label {Send to Add Trace...} \
    -command [list wviewer::browser_sea_send_to_add_trace $token $idxs]
  $m add command -command [list wviewer::browser_sea_copy_names $token $idxs] \
    -label [expr {$n == 1 ? {Copy name} : "Copy names ($n)"}]
  $m add separator
  set tp [wviewer::browser_sea_target_path $token $idxs]
  if {[lindex $tp 0] eq {ok}} {
    $m add command -label {Descend to here} \
      -command [list wviewer::browser_sea_descend_to $token $idxs]
  } else {
    $m add command -label {Descend to here} -state disabled
  }
  return $m
}

proc wviewer::browser_sea_menu_post {token W x y {rx -1} {ry -1}} {
  set ids {}
  catch {set ids [wviewer::browser_sea_menu_ids $token $W $x $y]}
  if {![llength $ids]} { return 0 }
  set m {}
  catch {set m [wviewer::browser_sea_menu_build $token $ids]}
  if {$m eq {}} { return 0 }
  set r 0
  catch {set r [wviewer::ctx_menu_popup $W $m $x $y $rx $ry]}
  return $r
}

proc wviewer::browser_sea_menu_unpost {token} {
  return [wviewer::ctx_menu_drop $token wvseamenu]
}

# --- THE HOVER TOOLTIP (PLAN item 11's eighth gesture, paid by item 20) -------
#
# ⚠⚠ THIS IS AN ACKNOWLEDGED MISS BEING PAID, NOT A NEW FEATURE. PLAN item 11's
# scope names "Tooltip on hover shows `browser_label_full`" and item 11 shipped
# SEVEN binds on this canvas, not eight (11_receipt.md §8). It belongs beside
# item 20 because it is the same defect wearing the other sign: the pane shows a
# LABEL and gave the user no way to see the NAME behind it. Item 20 lets them
# filter on what they see; this lets them find out what they are seeing.
#
# ⚠ ONE BIND, and the teardown is CODE rather than a second bind. `<Leave>`
# would be an eighth `bind $f.` line that documents no gesture, and item 11's
# own rule is that every such line has a `data-bseq` row in the guide. So the
# tip watches the pointer instead: while one is up, `browser_sea_tip_watch`
# re-arms every SEATIPPOLL ms and drops it as soon as `winfo containing` stops
# answering the canvas. Measured cost: one `after` token, and only while a tip
# is actually posted.
#
# ⚠ `balloon` (xschem.tcl:12551) COULD NOT BE REUSED, and the reason is in its
# first line: it BAKES its string into an `<Enter>` binding at attach time. This
# tooltip's text changes per CELL, forty times across one pane, so a baked
# string is the one thing it cannot be. `browser_rawbar_sync`'s ⚠ records the
# same finding from the other side (it re-attaches the balloon on every load).
#
# ⚠ THE FOUR VARIABLES LIVE IN THE `namespace eval wviewer` BLOCK AT THE TOP OF
# THIS FILE, beside browsersea/browserseasel and the rest, NOT here. This point
# in the file is OUTSIDE any namespace — every proc below is spelled
# `wviewer::…` precisely because of that — so a bare `variable` here would mint
# a GLOBAL, and every `variable seatipdelay` inside a proc would then find an
# empty namespace one instead. Two spellings of the delay, and the one a test
# writes would not be the one the code reads.
#
# THE DELAY IS A VARIABLE, not a literal, for the same reason `balloon` takes
# one: a tooltip that appears on the first pixel of movement is noise. A test
# sets it to 0 and restores it — that is a supported knob, not a back door.

# The tip window for a token: a child of the CANVAS, so `destroy $c` takes it.
proc wviewer::browser_sea_tip_path {token} {
  set c [wviewer::browser_sea_canvas $token]
  if {$c eq {}} { return {} }
  return $c.seatip
}

# Take the tip down and cancel anything pending. IDEMPOTENT and never throws —
# it is called from the teardown paths, where a half-built window is legal.
proc wviewer::browser_sea_tip_hide {token} {
  variable seatipafter
  variable seatipidx
  if {[info exists seatipafter($token)]} {
    catch {after cancel $seatipafter($token)}
    unset seatipafter($token)
  }
  set t [wviewer::browser_sea_tip_path $token]
  if {$t ne {}} { catch {destroy $t} }
  catch {unset seatipidx($token)}
  return 1
}

# THE WATCHDOG, and the reason there is no `<Leave>` bind. Re-arms while the tip
# is up; the moment the pointer is over something else — another widget, another
# window, off the screen — the tip goes.
proc wviewer::browser_sea_tip_watch {token} {
  variable seatipafter
  variable seatippoll
  set t [wviewer::browser_sea_tip_path $token]
  if {$t eq {} || [catch {winfo exists $t} e] || !$e} {
    return [wviewer::browser_sea_tip_hide $token]
  }
  set c [wviewer::browser_sea_canvas $token]
  set over {}
  # ⚠ `eval`, not `{*}`: `{*}` is Tcl 8.5 and this codebase targets 8.4 upwards.
  # `balloon_show` (xschem.tcl:12567) spells the same containment test the same
  # way, for the same reason.
  catch {set over [eval winfo containing [winfo pointerxy $c]]}
  if {$c eq {} || $over ne $c} { return [wviewer::browser_sea_tip_hide $token] }
  set seatipafter($token) \
    [after $seatippoll [list wviewer::browser_sea_tip_watch $token]]
  return 1
}

# POST the tip for one cell. Returns the text posted, or {} when it declined —
# which is an ANSWER (the row went, the pointer left, the canvas died), never a
# silent nothing.
#
# ⚠ THE TEXT IS `browser_sea_name`, i.e. THE FULL RAW NAME, resolved through the
# row INDEX exactly as every other gesture does. That is the whole point of the
# tooltip and it is also R8's rule restated: the label is a display, the index is
# the identity.
proc wviewer::browser_sea_tip_show {token idx {rx -1} {ry -1}} {
  variable seatipidx
  variable seatipafter
  variable seatippoll
  set c [wviewer::browser_sea_canvas $token]
  if {$c eq {}} { return {} }
  set nm [wviewer::browser_sea_name $token $idx]
  if {$nm eq {}} { return {} }
  set t $c.seatip
  catch {destroy $t}
  if {[catch {
    toplevel $t -bd 1 -background black -takefocus 0
    wm overrideredirect $t 1
    label $t.txt -justify left -takefocus 0 -fg black -background lightyellow \
      -font AseEntryFont -text $nm
    pack $t.txt
  }]} {
    catch {destroy $t}
    return {}
  }
  if {![string is integer -strict $rx] || $rx < 0} {
    catch {set rx [expr {[winfo pointerx $c] + 14}]}
  }
  if {![string is integer -strict $ry] || $ry < 0} {
    catch {set ry [expr {[winfo pointery $c] + 18}]}
  }
  catch {wm geometry $t \
    [winfo reqwidth $t.txt]x[winfo reqheight $t.txt]+$rx+$ry}
  catch {raise $t}
  set seatipidx($token) $idx
  # ⚠ THE WATCHDOG IS ARMED ON A DELAY, NEVER CALLED SYNCHRONOUSLY HERE. Two
  # reasons and both are real: a containment test at the instant of posting
  # answers a question we have just decided (we post BECAUSE the pointer was
  # over a cell), and a synchronous call makes the tip untestable — a suite
  # posts it programmatically while the real pointer is somewhere else
  # entirely, and the watchdog would take it down before the check could read
  # it. One poll interval is also the worst-case staleness after the pointer
  # leaves, which is the number that actually matters.
  set seatipafter($token) \
    [after $seatippoll [list wviewer::browser_sea_tip_watch $token]]
  return $nm
}

# `<Motion>` — the eighth gesture. Resolves the cell under the pointer and
# schedules the tip; a MISS, or a move to a different cell, takes the current
# one down first.
#
# ⚠ IT RETURNS EARLY WHEN THE CELL HAS NOT CHANGED, and that is not an
# optimisation: without it every pixel of movement inside one cell would cancel
# and re-arm the timer, so the tip would never appear at all while the user's
# hand is still moving.
proc wviewer::browser_sea_tip {token W x y} {
  variable seatipdelay
  variable seatipafter
  variable seatipidx
  set i [wviewer::browser_sea_hit $token $W $x $y]
  if {[info exists seatipidx($token)] && $seatipidx($token) == $i} { return $i }
  if {[info exists seatipafter($token)]} {
    catch {after cancel $seatipafter($token)}
    unset seatipafter($token)
  }
  set t [wviewer::browser_sea_tip_path $token]
  if {$t ne {}} { catch {destroy $t} }
  catch {unset seatipidx($token)}
  if {$i < 0} { return -1 }
  set rx -1 ; set ry -1
  catch {set rx [expr {[winfo pointerx $W] + 14}]}
  catch {set ry [expr {[winfo pointery $W] + 18}]}
  set d $seatipdelay
  if {![string is integer -strict $d] || $d < 0} { set d 600 }
  set seatipafter($token) \
    [after $d [list wviewer::browser_sea_tip_show $token $i $rx $ry]]
  return $i
}

# --- TWO-PANE item 9: the LOWER pane's widgets --------------------------------
# Build `$parent.sea`, the "sea of names" -- the lower pane of the two-pane
# browser. EMPTY in item 9: this is the container and its scrolling, nothing
# draws into it until item 11.
#
# ⚠ A `canvas`, and the alternatives were enumerated and REJECTED against
# Tk 8.6.14 rather than skipped (spec §5.1): `ttk::treeview` with N columns has
# NO cell selection in 8.6, so an N-column layout could only ever select N
# unrelated signals at once; side-by-side `listbox`es have no per-item font and
# each owns its own selection, so Shift-click cannot cross a column; a `text`
# widget yields character-range selection. The canvas gives column-major flow,
# multi-select, per-item styling and O(1) hit-testing (the flow is a regular
# grid, so `browser_flow_hit` is arithmetic, not `find closest`).
#
# ⚠ HORIZONTAL SCROLLING ONLY, AND NO `-yscrollcommand` AT ALL (R3). It is not
# an omission: the flow is column-major and the scrollregion's height is clamped
# to the widget, so a name is never below the fold -- it is only ever to the
# right. A vertical scrollbar here would be a silent design change.
#
# Returns the pane's path, so the caller adds it to the panedwindow without
# respelling it.
# ⚠ TWO-PANE item 11 ADDED `$w.st`, THE PANE'S OWN CAPTION — spec §7.2's line.
# It is a THIRD child of this frame, which reds the item-9 check that pinned the
# child set to exactly {c hsb}; that check is restated rather than relaxed.
# Why here and not on the sidebar's `.ph` status line: `.ph` says
# `<matched> of <total> signals` about the WHOLE inventory and a dozen checks
# across four files assert its text BYTE-IDENTICALLY. §7.2's sentence is about
# the SELECTED NODE — a different fact about a different set — and it belongs
# under the list it describes. The full reasoning, with the measured blast
# radius of each alternative, is in browser_sea_say.
#
# ⚠ `-width 1` IS NOT A SIZE, IT IS A STABILITY GUARANTEE. A label whose
# requested width tracks its text would re-request on every sentence change,
# the frame would re-request, the canvas would get <Configure>, and <Configure>
# refreshes the sea — which writes the caption. `-width 1` + `pack -fill x`
# gives the geometry manager a CONSTANT request, so the loop cannot start.
# `.ph` carries `-width 22` for the same reason.
proc wviewer::browser_sea_build {parent} {
  set w $parent.sea
  catch {destroy $w}
  frame $w -background [ase::theme panel]
  canvas $w.c -takefocus 1 -highlightthickness 0 \
    -background [ase::theme table] \
    -xscrollcommand [list $w.hsb set]
  scrollbar $w.hsb -orient horizontal -command [list $w.c xview]
  label $w.st -anchor w -justify left -width 1 \
    -font AseLabelFont -background [ase::theme panel] -text {}
  pack $w.st  -side bottom -fill x
  pack $w.hsb -side bottom -fill x
  pack $w.c   -side top -fill both -expand 1
  return $w
}

# The split between the two panes, as a FRACTION of the panedwindow's height
# (M3). `want` {} reads/re-applies the current one; a fraction strictly inside
# (0,1) sets it. Returns the fraction in force, or 0 when it could not be
# applied. ⚠ ITS HEADER USED TO SAY "PERSISTENCE IS ITEM 14 -- this is only the
# accessor and the apply". TWO-PANE ITEM 14 HAS LANDED: the persisted half is the
# pure preference READER and the single drop WRITER defined immediately below
# this proc, and this proc stayed the LAYOUT accessor with its contract
# unchanged, deliberately -- see the two ⚠⚠ paragraphs on that reader for what
# changing it instead would have broken.
#
# ⚠ THE TWO NEIGHBOURS ARE DESCRIBED, NEVER SPELLED, HERE AND EVERYWHERE ELSE IN
# THIS FILE. BD06/BW59-style checks count a BARE NAME file-wide and expect the
# call sites they enumerate; a mention in prose is indistinguishable from a call
# site, which is how two-pane item 12 red BD06. Each of the two is therefore
# written exactly twice in this file -- its `proc` line and its one caller (the
# state reader for one, the `<ButtonRelease-1>` bind for the other) -- and any
# comment that wants to point at one points at it by ROLE.
#
# ⚠⚠ A FRACTION, NEVER PIXELS, and both halves of that were forced by reading
# the code rather than by taste:
#   * the sidebar's height is the toplevel's, and the toplevel is resized
#     freely, so a pixel split restored onto a shorter window puts the sash
#     off the bottom;
#   * `browser_state` validates `width` with `string is integer -strict` and
#     zeroes anything else, so the sash could NOT have ridden inside that key as
#     a `{450 0.4}` list -- it would have been silently discarded (spec §9).
#
# ⚠⚠ IT MAY ONLY BE APPLIED ON A MAPPED PANEDWINDOW. MEASURED on this machine:
# before mapping, `winfo height` on a ttk::panedwindow is 1 and `sashpos 0` is
# 0, so `fraction x height` is 0 and the tree pane COLLAPSES to nothing. The
# height guard below is what makes "not mapped yet" a NO-OP returning 0 rather
# than a wrong answer that looks like a user preference.
proc wviewer::browser_sash {token {want {}}} {
  variable windows
  variable browsersash
  if {![dict exists $windows $token]} { return 0 }
  set pw [dict get $windows $token top].wvbrowser.pw
  if {[catch {winfo exists $pw} e] || !$e} { return 0 }
  # ⚠⚠ THE STORE IS DELIBERATELY ABOVE THE `$h <= 1` GUARD BELOW, AND THE ORDER
  # OF THESE TWO BLOCKS IS THE WHOLE DIFFERENCE BETWEEN "a snapshot taken with
  # the browser closed keeps the user's split" and "it silently forgets it".
  # STORING is always possible; APPLYING needs a mapped pane. Move this after
  # the guard and a restore into a never-shown sidebar drops the preference on
  # the floor -- which was fully green across three suites until BP77 in
  # `test_wave_sigbrowser_i1315.tcl` was added by the item's verification fixup.
  if {[string is double -strict $want] && $want > 0 && $want < 1} {
    set browsersash($token) $want
  }
  # 0.55 gives the tree the larger share, which is the pane the user navigates
  # with; the sea reflows to whatever is left (its rows-per-column is derived
  # from the height, so it has no preferred size to honour).
  #
  # ⚠⚠ TWO-PANE ITEM 14 MADE THE LAYOUT DEFAULT A **LOCAL**, AND THAT ONE-LINE
  # CHANGE IS THE WHOLE REASON THE PERSISTENCE IS EXPRESSIBLE. It used to SEED
  # the array (`set browsersash($token) 0.55`), and `browser_show` calls this
  # proc twice on its pack branch -- so after any show, a window nobody had
  # touched carried a stored 0.55 and "has a preference" and "has been shown"
  # were the same fact. With the default held here, `[info exists
  # browsersash($token)]` means EXACTLY "somebody chose a split", which is what
  # lets the state reader answer spec §9's `sash 0` on a fresh window and keeps
  # the whole-dict compare in `browser_state_is_default` closable.
  # Restoring the seed is a one-line revert and it is the item's sabotage S7.
  # ⚠ THE PLAN PREDICTED "BP69, BP41, BP42 and MG9 -- four oracles across three
  # files". THAT PREDICTION IS WRONG AND WAS MEASURED WRONG THREE TIMES (by the
  # item, by its verifier, and again by the fixup). BP41, BP42 and MG9 all read
  # windows whose sidebar was NEVER SHOWN, and the seed is only written once
  # this proc has RUN -- which happens from `browser_show`'s pack branch. They
  # MEASURE GREEN: `test_wave_modes.tcl` 488 and
  # `test_wave_sigbrowser_panes.tcl` 81, both untouched.
  # ⚠ WHAT IT ACTUALLY REDS, MEASURED ON THIS TREE: BP69 and BP77 in
  # `test_wave_sigbrowser_i1315.tcl` (186 passed / 2 failed, count held at 188).
  # BP69 sees the fresh window's preference become 0.55 and its third leg names
  # `sash` as a new departure; BP77 sees it because the apply that precedes it
  # calls this proc, and the seed puts a preference into a window nobody chose
  # one for -- which is the defect stated exactly. Before the fixup added BP77
  # the answer was BP69 ALONE (183/1). BP69's leg 2 ("the live split really is
  # non-zero") is what stops either from going green on an unmapped pane.
  set frac 0.55
  if {[info exists browsersash($token)]} { set frac $browsersash($token) }
  set h 0
  catch {set h [winfo height $pw]}
  if {$h <= 1} { return 0 }
  catch {$pw sashpos 0 [expr {int($frac * $h)}]}
  return $frac
}

# THE PERSISTED PREFERENCE, and it is a SEPARATE proc from the accessor above on
# purpose. TWO-PANE item 14; spec §9. PURE -- no widget, no window, no throw.
#
# ⚠⚠ WHY IT IS NOT THE ACCESSOR, WHICH IS THE ONE MISTAKE THIS ITEM EXISTS TO
# AVOID. The accessor's read arm APPLIES the split and answers the LAYOUT
# DEFAULT (0.55) for a window nobody has dragged. Read THAT from the state
# reader and `browser_state_is_default` compares 0.55 against the dict default
# and is FALSE FOREVER: every viewer's snapshot grows a `browser` key, and MG9
# in test_wave_modes.tcl -- a file the two-pane batch does not own -- goes red
# along with BP41 and BP42.
#
# ⚠⚠ AND WHY THE ACCESSOR'S RETURN CONTRACT WAS NOT SIMPLY CHANGED INSTEAD.
# test_wave_sigbrowser_sea.tcl captures the accessor's answer, squeezes the pane
# to 0.90 and restores it. If the read arm started answering 0 for a
# never-dragged window, that capture would be 0, the restoring call would be
# refused by the `$want > 0` guard, and the sea would stay squeezed for the rest
# of that file -- a fixture leak surfacing as unrelated reds. Two readers, two
# contracts, both explicit.
#
# ⚠ IT MUST WORK ON A HIDDEN SIDEBAR. A snapshot can be taken with the browser
# unpacked (BP57 does exactly that); the accessor's `$h <= 1` guard would answer
# 0 there and silently discard a preference the user really set.
proc wviewer::browser_sash_pref {token} {
  variable browsersash
  if {![info exists browsersash($token)]} { return 0 }
  return $browsersash($token)
}

# THE ONLY GESTURE THAT WRITES THE PREFERENCE: the user let go of the sash.
# Reads the LIVE split off the mapped panedwindow, turns it into a fraction and
# hands it to the accessor -- so the array still has exactly ONE writer and the
# fraction-not-pixels rule is enforced in exactly one place. Returns the stored
# fraction, or 0 when there was nothing sane to store. TWO-PANE item 14.
#
# ⚠ A FRACTION, COMPUTED HERE. Storing `$p` instead of `$p / $h` is the item's
# sabotage S2: the accessor's `$want > 0 && $want < 1` guard then REFUSES every
# real pixel count, so a drag would store nothing at all and BP70 goes red --
# a pixel bug that fails closed rather than restoring a sash off the bottom of
# a shorter window.
#
# ⚠ `$h <= 1` IS "NOT MAPPED", not an error: this can be reached from a release
# delivered while the pane is being torn down.
proc wviewer::browser_sash_drop {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set pw [dict get $windows $token top].wvbrowser.pw
  if {[catch {winfo exists $pw} e] || !$e} { return 0 }
  set h 0
  catch {set h [winfo height $pw]}
  if {$h <= 1} { return 0 }
  set p {}
  if {[catch {$pw sashpos 0} p]} { return 0 }
  if {![string is integer -strict $p]} { return 0 }
  set frac [expr {$p * 1.0 / $h}]
  if {$frac <= 0 || $frac >= 1} { return 0 }
  return [wviewer::browser_sash $token $frac]
}

# --- item 9: state + refresh --------------------------------------------------

# Re-read the window's raw inventory into the SNAPSHOT. THE ONLY raw read in the
# browser, and it goes through `wviewer::signal_list` — settled decision 13: the
# browser's content derives from `xschem raw list`, NEVER from the rect model
# (issue 0186 is open and blanks the document under a CIW `xschem reload`).
#
# A SNAPSHOT rather than a live read, `atdsigs`-shaped (item 5's precedent), is
# also why a keystroke in either bar costs no context loan: the 0173 bracket is
# taken HERE, once per show, not once per character.
proc wviewer::browser_reload {token} {
  variable windows
  variable browsersigs
  variable browserdbsigs
  variable browserraw
  variable browsercurdb
  if {![dict exists $windows $token]} { return 0 }
  # --- issue 0313: A REFUSED LOAN MUST NOT EMPTY THE SIDEBAR ------------------
  #
  # ⚠⚠ THIS IS THE STEP THAT CLEARED IT. The snapshot below is the browser's
  # whole model — `browsersigs` feeds the tree's node set AND the lower pane —
  # and it used to be overwritten with whatever `signal_list` returned, `{}`
  # included. A `{}` from a REFUSED context loan is not "the viewer has no
  # signals"; on the gesture path (issue 0314) it was every single time. So a
  # Ctrl-Alt-V that merely REFUSED left the user with a tree collapsed to its
  # bare design root, an empty pane, and a notice reading as "this pane is
  # empty" instead of "the digital pane you asked for is missing" — MEASURED:
  # `PANE ROWS 2 -> 0`, `TREE top=1 rows=g:/0`, `browsersea 0 entries`.
  #
  # ⚠ AND IT COULD NOT BE CLICKED BACK. The re-landed row is the one already
  # selected, so ttk's `selection set` is a no-op, no <<TreeviewSelect>> is
  # queued, and nothing rebuilds — only an unrelated control (the class filter)
  # brought the listing back. RULING F1b: a refusal FALLS THROUGH, it does not
  # strand the user. Keeping the previous snapshot is what makes that true here:
  # the analog listing the refusal was supposed to fall back onto is still the
  # one on screen, and F5's sentence lands on it exactly as designed.
  #
  # The fix for 0314 makes the gesture path stop refusing at all; this arm is
  # what a refusal that is REAL (semaphore >= 2 — a modal dialog, a placement in
  # flight — or a viewer being torn down) is allowed to cost: one skipped
  # refresh, never a wiped browser.
  set names {}
  set st ok
  foreach e [wviewer::signal_list $token st] { lappend names [dict get $e name] }
  if {$st eq {refused}} {
    return [expr {[info exists browsersigs($token)] ? [llength $browsersigs($token)] : 0}]
  }
  set browsersigs($token) $names
  # item 14: the FOREIGN databases' inventories, in the SAME snapshot. Taken
  # UNCONDITIONALLY — the checkbox is read in exactly one place (browser_refresh)
  # and this proc is not it, so the tree can be re-scoped on a toggle without
  # re-entering the engine. With a single raw loaded this costs one `raw info`
  # and no DB switch at all.
  set foreign {}
  # item 10 (two-pane): the CURRENT DB's raw path, captured in the same pass, at
  # zero extra engine cost — `browser_root_label` turns it into the tree's design
  # root text. It is captured HERE, in the one proc that already holds the 0173
  # context loan, rather than read in `browser_refresh`: refresh rides both
  # searchbars' <KeyRelease> pump and must not take a loan per character.
  # TWO-PANE item 15 (spec R7): the current DB's HEADER IDENTITY, captured in the
  # very same pass and at the same zero extra cost. With All-DBs ticked the
  # current DB is a top-level node like every other DB, and it needs the same two
  # facts a foreign one does — the `d:<registry idx>` id and the label. Its
  # SIGNAL NAMES are deliberately NOT captured here: those still come from
  # `signal_list` above, which stays the authority for the current DB (decision
  # 13, BD07), and a second copy could disagree with it.
  set curraw {}
  set curdb {}
  set ast ok
  set acode [catch {
    foreach db [wviewer::signal_list_all $token ast] {
      # ⚠ RULING F4: the `type` key rides along on BOTH dicts, at zero extra
      # engine cost -- `signal_list_all` already read it out of `xschem raw info`.
      # It is the ONE fact that says whether an inventory's names obey SPICE's
      # device-class grammar or Verilog's, and without it every entry built from
      # this snapshot would be classified as if it came out of ngspice.
      if {[wviewer::dget $db cur 0]} {
        set curraw [wviewer::dget $db path {}]
        set curdb [dict create \
          id    "d:[wviewer::dget $db idx {}]" \
          label [wviewer::dget $db label {}] \
          type  [wviewer::dget $db type {}]]
        continue
      }
      lappend foreign [dict create \
        id    "d:[wviewer::dget $db idx {}]" \
        label [wviewer::dget $db label {}] \
        path  [wviewer::dget $db path {}] \
        type  [wviewer::dget $db type {}] \
        names [wviewer::dget $db names {}]]
    }
  }]
  # issue 0313, SECOND HALF (review finding). The three snapshots below are the
  # same kind of model as `browsersigs` — the tree's per-database groups, the
  # design root's label, the current DB's identity — and this read can fail the
  # same two ways: a REFUSED loan (`ast`), or a THROW that the `catch` above
  # would otherwise turn into three silent empties (`signal_list_all` re-raises
  # its body's errors, and its leave_ctx/retitle tail is outside that inner
  # catch). Either way the answer is not an answer, so the previous snapshot
  # stands: one skipped refresh, never a wiped browser.
  if {$ast eq {refused} || $acode} { return [llength $names] }
  set browserraw($token) $curraw
  set browsercurdb($token) $curdb
  set browserdbsigs($token) $foreign
  return [llength $names]
}

# 1 when THIS window's Search bar has its All-DBs box ticked. THE ONE AND ONLY
# READ OF THAT CHECKBOX — every scoping decision goes through here, so there is
# a single place a sabotage can land and a single place to look when the scope
# is wrong. `dget ... 0` because the key is present only on a bar built with
# `-alldbs 1` (BAR11 pins the plain bar's dict to exactly four keys).
proc wviewer::browser_alldbs {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set d {}
  catch {set d [wviewer::searchbar_get $top.wvbrowser.wvsearch]}
  return [expr {[wviewer::dget $d alldbs 0] ? 1 : 0}]
}

# --- spec §F, RULING F4: WHICH KIND OF DATABASE IS THE CURRENT ONE? ----------
#
# THE ONE AND ONLY READ of the current database's `sim_type` on the browser side,
# for the same reason the All-DBs checkbox reader directly above is the only read
# of its box: a classification sabotage then has exactly one place to land, and a
# wrong classification has exactly one place to look.
#
# ⚠ THAT READER IS DELIBERATELY NOT NAMED IN THIS COMMENT. `BD06`
# (tests/headless/test_wave_sigbrowser_i14.tcl) counts its bare name over the
# WHOLE FILE and expects 2 — defined once, called once — so a comment that spells
# it reds a check about scoping for a reason that has nothing to do with scoping.
# MEASURED: the first cut of this block did exactly that.
#
# It answers out of
# the SNAPSHOT `browser_reload` already took, never by re-entering the engine --
# it is called once per keystroke by `browser_match` and once per own-level signal
# by `browser_sea_own`, and a `raw info` on either path would be a context loan
# taken inside the search pump.
#
# ⚠ AN UNKNOWN TOKEN, A SNAPSHOT THAT WAS NEVER TAKEN AND A `signal_list_all`
# THAT THREW ALL ANSWER `{}` -- which `db_is_digital` reads as ANALOG, i.e. as
# exactly the behaviour that shipped before this ruling. The degradation
# direction is deliberate: a guessed "digital" would stop declassing a real
# ngspice raw and put `m`, `v` and `@m` back at the top of the tree, undoing
# issue 0217 on a wrong guess. Guessing analog costs a digital name its class on
# a browser that has no snapshot to draw anyway.
proc wviewer::browser_curtype {token} {
  variable browsercurdb
  if {![info exists browsercurdb($token)]} { return {} }
  return [wviewer::dget $browsercurdb($token) type {}]
}

# --- TWO-PANE item 12: R11's TWO CLASS FILTERS STOP BEING INERT ---------------
#
# One accessor per checkbox, each THE ONE AND ONLY READ OF ITS BOX — the same
# rule the All-DBs reader directly above is built on, for the same reason: a
# scoping sabotage has exactly one place to land and a wrong scope has exactly
# one place to look. BW59 counts each bare name file-wide and expects 2 (defined
# once, called once), which is BD06's rule.
#
# ⚠⚠ NO ACCESSOR IS NAMED IN ANY COMMENT IN THIS FILE, AND THAT INCLUDES THE ONE
# ABOVE. Those counts are BARE-NAME greps over the whole source, so a mention in
# prose is indistinguishable from a call site. Naming the All-DBs reader in this
# very block is what turned BD06 red on item 12's first green run — it counted 3
# where it demands 2. The rule costs one awkward sentence and buys a check that
# cannot be fooled; the blocks below therefore say "the two boxes".
#
# ⚠ AN UNKNOWN TOKEN ANSWERS R11's DEFAULT, never {} and never a throw. The two
# arrays are seeded per token in browser_build, so "not built yet" and "torn
# down" are both reachable -- and `{}` reaching browser_class_filter's
# `if {$devint && $srccur}` is a THROW, not a filter. BW57.
#
# ⚠ THE TWO DEFAULTS DIFFER (0 and 1). That is R11, not an asymmetry to be
# tidied away: a copy-paste that gives both boxes the same default reds BW56 and
# collapses BW60's four totals to two.
#
# ⚠ PER TOKEN, NOT PER NAMESPACE. Seeding a scalar instead of the array element
# makes a second viewer inherit the first one's boxes; BW58's last leg is that.
#
# `want` is optional so the accessor is both the read and the write, which keeps
# the setter from becoming a second place that knows the default.
proc wviewer::browser_devint {token {want {}}} {
  variable browserdev
  if {$want ne {}} { set browserdev($token) [expr {$want ? 1 : 0}] }
  if {![info exists browserdev($token)]} { return 0 }
  return [expr {$browserdev($token) ? 1 : 0}]
}
proc wviewer::browser_srccur {token {want {}}} {
  variable browsersrc
  if {$want ne {}} { set browsersrc($token) [expr {$want ? 1 : 0}] }
  if {![info exists browsersrc($token)]} { return 1 }
  return [expr {$browsersrc($token) ? 1 : 0}]
}

# Both bars -> browser_and. Returns {ok <names>} / {err <msg>}.
#
# ⚠ IT READS BOTH BARS ITSELF and the callback's own `pat/syn/case/type`
# arguments are DELIBERATELY IGNORED (see browser_search_cb). That is what makes
# it structurally impossible for one route to apply one bar and not the other —
# a callback that used its own arguments would apply whichever bar fired.
proc wviewer::browser_match {token} {
  variable windows
  variable browsersigs
  if {![dict exists $windows $token]} { return [list ok {}] }
  if {![info exists browsersigs($token)]} { return [list ok {}] }
  set f [dict get $windows $token top].wvbrowser
  set d1 [wviewer::searchbar_get $f.wvsearch]
  set d2 [wviewer::searchbar_get $f.wvfilter]
  # ⚠⚠ TWO-PANE ITEM 20: THE SUBJECT IS THE LABEL THE LOWER PANE DRAWS. This is
  # ONE of the TWO places the key is spelled — the other is browser_refresh's
  # All-DBs loop, which matches each FOREIGN inventory with these same two bar
  # dicts. Both must pass it, or one pattern would mean "the label" for the
  # current DB and "the raw name" for every other one. BD57 is that check.
  # ⚠ RULING F4: the key is CURRIED with the current database's kind. Left as the
  # bare `browser_label_of` a VCD-current browser would match the bars against an
  # analog-classified label (`sig:i`) while the pane below draws `sig` -- item 20's
  # own defect, one database KIND over instead of one database over. FD36.
  return [wviewer::browser_and $browsersigs($token) $d1 $d2 \
            [list wviewer::browser_label_of_db [wviewer::browser_curtype $token]]]
}

# The status/error line — item 8's `.ph` label, repurposed. It keeps saying
# `Signal Browser` (BS22 asserts the label says what it is) and carries the
# count, or the matcher's message.
proc wviewer::browser_status {token msg} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set l [dict get $windows $token top].wvbrowser.ph
  if {[catch {winfo exists $l} e] || !$e} { return 0 }
  catch {$l configure -text "Signal Browser\n$msg"}
  return 1
}

# match -> browser_rows -> the treeview -> the status line. `reload` 1 re-reads
# the raw first (the show path); 0 re-filters the snapshot (every keystroke).
# Returns 1 when the tree was rewritten, 0 when it was deliberately held.
#
# ⚠ THIS PROC MUST NOT THROW. It rides both searchbars' <KeyRelease> pump, and
# a Tcl error there pops bgerror — modal under X, which HANGS a headless run.
# Same discipline as add_trace_filter and readout_refresh: EVERY exit is a
# guard, never an error.
#
# On `{err msg}` it HOLDS the last good tree (item 5's ruling) and mirrors the
# message into the status label. The mirror is not redundant: the bar's own
# `err` label is the FIRST widget to clip in a sidebar this narrow (receipt D1),
# so the status line is what actually keeps settled decision 4 visible.
proc wviewer::browser_refresh {token {reload 0}} {
  variable windows
  variable browsersigs
  variable browserrows
  variable browserdbsigs
  variable browserraw
  variable browsercurdb
  variable browserseaent
  variable browserseadbent
  # ⚠ DECLARED FOR THE TWO BAIL-OUTS BELOW, AND THE DECLARATION IS HALF OF THAT
  # FIX: without it their `set browserseanote($token) {}` addresses a LOCAL array,
  # writes nothing anybody reads, and the `catch` hides it — the leak shape this
  # file's siblings document for `gridshow`, `dest` and `browserwidth`, and the one
  # BE12 pins in `forget`.
  variable browserseanote
  if {![dict exists $windows $token]} { return 0 }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f.pw.tvf.tv} e] || !$e} { return 0 }
  if {$reload} { catch {wviewer::browser_reload $token} }
  if {![info exists browsersigs($token)]} { set browsersigs($token) {} }
  set total [llength $browsersigs($token)]
  if {[catch {wviewer::browser_match $token} r]} {
    wviewer::browser_status $token $r
    return 0
  }
  if {[lindex $r 0] ne {ok}} {
    wviewer::browser_status $token [lindex $r 1]
    return 0
  }
  set names [lindex $r 1]
  # --- TWO-PANE item 10: R5, AND THE TREE IS NOT WHAT THE BARS NARROW ---------
  #
  # ⚠⚠ THE TREE'S NODE SET COMES FROM THE **BAR-UNFILTERED** INVENTORY, and this
  # is spec §7.1 read literally: "the tree's node set is derived from the
  # unfiltered inventory (minus R11's class filter, which is not a search). A
  # pattern that matches nothing leaves the tree intact and the sea of names
  # empty." The rejected alternative is named there too — "pruning the tree to
  # nodes with surviving signals ... makes the navigation surface flicker under
  # the user's fingers while they type, which is the defect R5 exists to fix,
  # merely relocated."
  #
  # THE FLICKER IS NOT HYPOTHETICAL — IT WAS MEASURED on the first cut of this
  # item, which fed `$names` (the bar-matched set) straight into browser_rows:
  #   expand x1, then type `v(x1.x2*` one character at a time, as a user does.
  #   The FIRST character makes the shell pattern `v`, which matches NOTHING, so
  #   the tree empties; x1 is deleted, its open state dies with it, and the
  #   remaining seven keystrokes rebuild it CLOSED. The user's expansion is gone
  #   and no amount of open-set carrying inside browser_populate can save it,
  #   because the node did not exist to carry.
  #
  # ⚠ §6's "the tree, the sea of names, the status line and every gesture see
  # one consistent set" is NOT in conflict: that sentence is in the R11 section
  # and is about the CLASS FILTER, which §7.1 explicitly exempts from this rule
  # ("which is not a search"). The class filter still applies to the tree.
  #
  # ⚠ SCOPE, DECLARED: this governs the CURRENT DB only. The All-DBs branch
  # below still matches each foreign inventory with the bars, because R7's tree
  # shape — per-DB headers appearing and disappearing with the pattern — is
  # ITEM 15's, and BD51/BD51b pin today's behaviour. Changing both here would
  # make item 15's reds unattributable.
  #
  # ⚠ `browserrows($token)` therefore becomes the UNFILTERED rows, and it must:
  # every gesture resolves a tree row id THROUGH it (browser_leaf_names,
  # browser_plot_ids, browser_menu_ids, browser_target_path, browser_descend_to),
  # so a tree holding a node the row model does not describe is a broken gesture,
  # not a cosmetic mismatch. The bar-matched set is what item 11's sea and §7.2's
  # caption consume, and item 11 computes it below — from the SAME class-filtered
  # entry list, narrowed by name, so the two panes cannot disagree about what the
  # CLASS filter did (spec §6) while disagreeing about what the BARS did (§7.1).
  #
  # ⚠ RULING F4: ONE READ of the current database's kind, held in a local and
  # handed to every entry built from this inventory -- the same shape as the two
  # class boxes below. `browsersigs` is the CURRENT database's names alone, so
  # this one value describes all of them.
  set curtype [wviewer::browser_curtype $token]
  set entries {}
  foreach n $browsersigs($token) {
    lappend entries [wviewer::signal_entry $n $curtype]
  }
  # --- TWO-PANE item 10 -------------------------------------------------------
  # ⚠⚠ M6's PRE-FILTER `anypath` GATE IS DELIBERATELY *NOT* PASSED HERE, and the
  # reason is measured rather than stylistic. Two facts kill it:
  #
  #   1. It cannot change anything. `browser_rows`' flat branch is ALSO gated
  #      PER ENTRY on `$path ne {}`, so forcing the gate to 1 on a set whose
  #      surviving entries all have empty paths mints no groups — there are no
  #      segments to mint. And when the filter leaves even one pathed entry the
  #      auto-gate already answers 1. M6's stated failure mode ("designs flip to
  #      flat mode if the gate is computed after the class filter") therefore has
  #      no reachable state. Item 2's TP32 pins that as a value, and the
  #      "default the gate to 1" sabotage produced ZERO reds, which is the same
  #      fact from the other side.
  #   2. Passing it would be WRONG under All-DBs. One gate computed from the
  #      CURRENT DB's entries and applied to every group would flatten a
  #      hierarchical FOREIGN inventory whenever the current raw happens to be
  #      flat. The gate is per-inventory, and `browser_rows` already computes it
  #      per inventory.
  #
  # So the override exists, is unit-tested (item 2), and has no production
  # caller. That is stated here rather than papered over with a source-order
  # check that would pin dead code.
  #
  # R11's two class policies. ⚠⚠ TWO-PANE ITEM 12 REPLACED ITEM 10's HARDCODED
  # `0 1` WITH THE TWO BOXES. This comment used to NAME the two accessors, and
  # item 12 reworded it deliberately: BW59 counts each bare name over the whole
  # source and expects 2 (defined once, called once — BD06's rule), so naming one
  # here would make the count start at 1 and the rule stop meaning anything.
  #
  # ⚠ ONE READ OF EACH BOX, HELD IN A LOCAL AND USED TWICE — exactly the shape
  # `alldbs` below uses, and load-bearing for the same reason. The second use is
  # the All-DBs loop's own class filter: read the boxes AGAIN down there and the
  # two reads can drift, so one checkbox would govern the current DB's inventory
  # and not the next one's. Spec §6's "one consistent set" is the ruling and
  # BD58 is the check.
  #
  # Everything downstream — the tree, the sea, the status line and every gesture
  # — sees this ONE filtered set.
  set devint [wviewer::browser_devint $token]
  set srccur [wviewer::browser_srccur $token]
  set entries [wviewer::browser_class_filter $entries $devint $srccur]
  # --- TWO-PANE item 11: THE OTHER HALF, and it is a DIFFERENT SET -----------
  #
  # ⚠⚠ THE SEA IS WHAT THE BARS NARROW. `$entries` above is the tree's set,
  # bar-UNFILTERED per §7.1; `$names` is the bar-matched name list. Item 11's
  # first job is the intersection — and it is spelled as a NARROWING OF
  # `$entries` rather than as `class_filter(entries_of($names))` on purpose:
  #
  #   * ONE class_filter call for the current DB means the two panes provably
  #     agree about what R11's checkboxes did (spec §6's "one consistent set"),
  #     while §7.1 lets them disagree about what the BARS did. Two filter calls
  #     would let a future item change one and not the other, and the symptom
  #     would be a signal visible in the tree's node set but absent from every
  #     node's list, which reads as a display bug.
  #   * it preserves RAW-FILE ORDER (limit D7) for free, because `$entries` is
  #     already in it and this is a filter, not a rebuild.
  #   * a name appearing TWICE in one raw (legal) keeps both entries, because
  #     the test is membership of the NAME, not of the entry.
  set seakeep {}
  foreach n $names { lappend seakeep $n }
  array unset __seaidx
  array set __seaidx {}
  foreach n $seakeep { set __seaidx($n) 1 }
  set seaent {}
  foreach e $entries {
    if {[info exists __seaidx([wviewer::dget $e name {}])]} { lappend seaent $e }
  }
  array unset __seaidx
  # SET BEFORE browser_populate RUNS, and that ordering is load-bearing:
  # `browser_populate`'s `selection set` fires <<TreeviewSelect>>, which runs
  # browser_sea_refresh — mid-refresh. It must find THIS refresh's snapshot, not
  # the previous one's.
  set browserseaent($token) $seaent
  # §F item F6 (issue 0308): THE SEA'S PER-DATABASE DIMENSION, EMPTIED HERE AND
  # FILLED IN THE All-DBs LOOP BELOW — never carried over from the previous
  # refresh. A foreign inventory left behind after its database stopped matching
  # (or after the box was un-ticked) would be a pane listing a database the tree
  # no longer shows, which is the same wrong-answer shape one refresh later.
  set browserseadbent($token) {}
  # R2: the tree has exactly one root node per database, named for its design.
  #
  # ⚠ ONE READ OF THE All-DBs CHECKBOX, HELD IN A LOCAL AND USED TWICE. Its
  # accessor is pinned by BD06 as "defined once and CALLED once, FILE-WIDE" —
  # BD06 counts the bare name over the whole source, so even naming it in a
  # comment reds it. The rule exists so a scoping sabotage has exactly one place
  # to land, and one place to look when the scope is wrong.
  set alldbs [wviewer::browser_alldbs $token]
  set rp {}
  if {[info exists browserraw($token)]} { set rp $browserraw($token) }
  set root [wviewer::browser_root_label $rp]
  # --- TWO-PANE item 15 (spec R7 / §4.3): THE CURRENT DB GETS A HEADER TOO ----
  #
  # With the box OFF, group 0 stays flat and unlabelled and the row list is
  # byte-identical to what item 9 shipped (BD19's identity, BW52's node set).
  # With it ON, group 0 gains its own `d:<registry idx>` header and its own
  # design root, so the tree's TOP LEVEL is the per-DB headers — R7's sentence.
  #
  # ⚠⚠ THE FIFTH TUPLE ELEMENT IS AN EXPLICIT EMPTY PREFIX, AND IT IS THE WHOLE
  # RULING. The current DB's ROWS keep their unprefixed ids (`g:`, `g:x1`,
  # `s:v(n)`) even under a header, because the prefix would be the DB's REGISTRY
  # INDEX — which moves when raws load in another order or one is closed. Every
  # id `browser_tree_state` persisted would then name a row that no longer
  # exists and the user's selection and open set would silently evaporate.
  # MEASURED: test_wave_sigbrowser_i1315.tcl BP47b watches that index move 1 -> 0
  # across one snapshot/restore. §4.3 rules the same way.
  #
  # ⚠⚠ THE HEADER FOLLOWS THE CHECKBOX ALONE, NEVER "how many foreign DBs
  # matched". Gating it on the foreign count would make it appear and disappear
  # as the user types — a foreign DB that stops matching emits no header — and
  # every current-DB row would be re-parented mid-keystroke, destroying the open
  # set. That is §7.1's flicker one level up. BD70c pins it.
  #
  # A missing or empty capture degrades to the flat unlabelled group: no header,
  # no throw.
  set g0id {} ; set g0lab {}
  if {$alldbs && [info exists browsercurdb($token)]} {
    set g0id  [wviewer::dget $browsercurdb($token) id {}]
    set g0lab [wviewer::dget $browsercurdb($token) label {}]
    if {$g0id eq {} || $g0lab eq {}} { set g0id {} ; set g0lab {} }
  }
  if {$g0id ne {}} {
    set groups [list [list $g0id $g0lab $entries $root {}]]
  } else {
    set groups [list [list {} {} $entries $root]]
  }
  set extra 0
  set ndbs 0
  if {$alldbs} {
    # the SAME two bar dicts the current DB was matched with — the foreign
    # inventories go through browser_and, not through a second matcher, so the
    # AND, the type dropdowns and decision 4's error arm cannot drift per DB.
    #
    # ⚠⚠ TWO-PANE ITEM 20 ADDS THE KEY HERE TOO, and "the same two bar dicts"
    # above is why: a dict is only half of what a bar means — the other half is
    # the SUBJECT it is matched against. Key browser_match and not this loop and
    # one typed pattern would filter the current DB by the label the user can
    # see and every foreign DB by the raw name they cannot, with nothing on
    # screen to say which. BD57 pins it on the live All-DBs fixture.
    set d1 [wviewer::searchbar_get $f.wvsearch]
    set d2 [wviewer::searchbar_get $f.wvfilter]
    if {![info exists browserdbsigs($token)]} { set browserdbsigs($token) {} }
    foreach db $browserdbsigs($token) {
      # ⚠ RULING F4: THIS DB's OWN KIND, read once and used TWICE below -- as the
      # matcher key and as the classifier's input. It is per-DB and cannot be
      # hoisted: the whole point of the All-DBs tree is that an analog raw and a
      # VCD sit in it side by side, and one `curtype` applied to both would
      # declass the VCD or refuse to declass the raw.
      set dbtype [wviewer::dget $db type {}]
      set dr {}
      if {[catch {wviewer::browser_and [wviewer::dget $db names {}] $d1 $d2 \
                    [list wviewer::browser_label_of_db $dbtype]} dr]} {
        continue
      }
      if {[lindex $dr 0] ne {ok}} { continue }
      set dnames [lindex $dr 1]
      if {![llength $dnames]} { continue }
      set dent {}
      foreach n $dnames { lappend dent [wviewer::signal_entry $n $dbtype] }
      # spec 6: ONE consistent set. A foreign DB filtered differently from the
      # current one would make the same signal visible in one tree and not the
      # other, with the checkbox claiming to govern both.
      #
      # ⚠⚠ TWO-PANE ITEM 12: THE SAME TWO VALUES read ONCE at the top of this
      # proc, not a second read of the boxes. This is the site item 20 found the
      # hard way about `browser_and`'s two callers, one item over: wiring the
      # current-DB filter and leaving this one at item 10's literal `0 1` gives a
      # checkbox that governs the tree the user is looking at and silently not
      # the foreign inventory beside it. BD58 is that check, on the live All-DBs
      # fixture, because this is the only place it is reachable.
      set dent [wviewer::browser_class_filter $dent $devint $srccur]
      # §F item F6 (issue 0308): AND THE LOWER PANE GETS THE SAME LIST, in the
      # same pass, keyed by the same `d:<idx>` the group below is keyed by. One
      # write means the pane can never list a set the tree does not show, which
      # is the invariant §7.1 states for the current DB (there the tree is the
      # BAR-UNFILTERED set and the pane the bar-matched one; a foreign DB's tree
      # is already bar-matched — item 15's declared asymmetry, BD51/BD51b — so
      # for a foreign database the two sets are literally the same list).
      dict set browserseadbent($token) [wviewer::dget $db id {}] $dent
      # ⚠ TWO-PANE item 15: the FOURTH element is THIS DB's own design-root
      # label, derived from THIS DB's own raw path. Left off, every DB's root
      # would render the CURRENT design's name under a foreign DB's header — the
      # tree would say which run a node came from and be wrong. A seeded
      # inventory with no `path` key floors at `design` (BD58's fixture) rather
      # than borrowing the current design's name.
      lappend groups [list [wviewer::dget $db id {}] [wviewer::dget $db label {}] \
                        $dent \
                        [wviewer::browser_root_label [wviewer::dget $db path {}]]]
      incr extra [llength $dnames]
      incr ndbs
    }
  }
  # ⚠⚠ THE TWO BAIL-OUTS CLEAR §F ITEM F5's NOTICE, AND THAT IS ISSUE 0318's
  # SECOND HALF (adversarial review finding 2). Both arms are reached AFTER the
  # pane's own snapshot has been rewritten (`browserseaent` above), and both
  # `return` BEFORE the tail refresh — which is the ONE place the notice is
  # normally cleared. So a refresh that throws left a sentence describing a pane
  # that no longer exists, and since 0318 the next `<Configure>` KEEPS that
  # sentence instead of scrubbing it: the geometry path is deliberately no longer
  # the thing that cleans up after a failed navigation. A navigation that failed
  # is still a navigation, so it clears here, on the two paths that return early.
  # `catch`ed for this proc's usual reason — a bail-out must not throw on its way
  # out. ⚠ AND THE `variable browserseanote` AT THE TOP OF THIS PROC IS PART OF
  # THE FIX, NOT TIDINESS: without it this line writes a LOCAL array and the catch
  # swallows the failure. BZ19 is behavioural for exactly that reason.
  if {[catch {wviewer::browser_rows_multi $groups $root} rows]} {
    catch {set browserseanote($token) {}}
    wviewer::browser_status $token $rows
    return 0
  }
  if {[catch {wviewer::browser_populate $f.pw.tvf.tv $rows} pe]} {
    catch {set browserseanote($token) {}}
    wviewer::browser_status $token $pe
    return 0
  }
  set browserrows($token) $rows
  set st "[llength $names] of $total signals"
  if {$ndbs > 0} {
    append st ", +$extra from $ndbs other DB[expr {$ndbs == 1 ? {} : {s}}]"
  }
  wviewer::browser_status $token $st
  # --- TWO-PANE item 11: THE TAIL, and it is not redundant --------------------
  # browser_populate already fired <<TreeviewSelect>> above — but ONLY when the
  # selection actually CHANGED. Type a character that narrows nothing away and
  # the same node stays selected, ttk fires nothing, and without this call the
  # sea would keep showing the previous match set while the bar says otherwise.
  # MEASURED as the sabotage "drop the tail call": a bar keystroke stops moving
  # the sea.
  catch {wviewer::browser_sea_refresh $token}
  return 1
}

# Apply a row list to a treeview — TWO-PANE item 10.
#
# ⚠⚠ THE PROJECTION LIVES HERE, NOT IN THE CALLER, and that is the whole reason
# it is one line. `browser_populate` has TWO callers: `browser_refresh` and
# `browser_show_path`'s improve-or-restore arm, which hands back the FULL saved
# row list. Projecting in the caller would leave that second path re-inserting
# leaves into a tree that must not have any, and only an X-arm check would ever
# see it.
#
# THREE CHANGES FROM THE SINGLE-PANE VERSION, all of them spec rulings:
#
#  * R1/R3 — ONLY NODES. Leaf rows never enter the tree; signals live in the
#    lower pane now. `browserrows($token)` still holds the FULL list, so
#    browser_leaf_names, browser_plot_ids, browser_menu_ids, browser_target_path
#    and browser_descend_to are untouched and R6's recursive plot still works.
#  * R1/M11 — COLLAPSED BY DEFAULT, except the design root — and, under R7,
#    except the DB header that root now hangs from (TWO-PANE item 15; see the
#    ⚠ block on the open rule below). "Collapsed by default" taken literally
#    including the root renders the whole tree as one line, which is not
#    navigation. ⚠ SPEC §4.1 SAYS "Inserted closed (-open 0) — R1. This is the
#    single change in browser_populate"; item 15 makes it two, and the receipt
#    records the divergence rather than the code hiding it.
#  * R4 — THE SELECTION IS NEVER EMPTY. The previous selection is restored when
#    it survived, otherwise the design root is selected. ⚠ AND IT IS NARROWED TO
#    ONE ID HERE: `-selectmode browse` gates only ttk's CLASS BINDINGS
#    (/usr/share/tcltk/tk8.6/ttk/treeview.tcl:262-275), so `selection set` with
#    two ids really does select two — the widget will not narrow it for us.
#
# ⚠⚠ AND THE OPEN SET SURVIVES A REPOPULATE, which is R5 and was NOT free.
# Every keystroke in either searchbar runs `browser_refresh`, which runs this
# proc, which deletes every row. While rows were re-inserted `-open 1` that was
# invisible; the moment item 10 inserts them `-open 0` it becomes "typing in the
# Search bar collapses everything you had expanded". R5's letter is "the tree
# never auto-OPENS on a search"; auto-CLOSING is the same defect wearing the
# other sign, and it is the one this rebuild introduces. So the previously-open
# ids are carried across. A node that did not exist before the repopulate is
# still born CLOSED — this restores state, it does not invent it.
#
# ⚠ `$tv see` IS NOT CALLED, AND MUST NOT BE. `see` force-opens every ancestor
# of its target (browser_reveal's central finding), which would undo
# collapsed-by-default on every keystroke in either searchbar. Only a
# user-initiated reveal may reach it (spec §4.2).
proc wviewer::browser_populate {tv rows} {
  set prev {}
  catch {set prev [$tv selection]}
  set wasopen {}
  foreach id [wviewer::browser_tree_nodes $tv] {
    set o 0
    if {[catch {$tv item $id -open} o]} { continue }
    if {[string is boolean -strict $o] && [string is true -strict $o]} {
      lappend wasopen $id
    }
  }
  set existed [wviewer::browser_tree_nodes $tv]
  $tv delete [$tv children {}]
  set nodes [wviewer::browser_tree_rows $rows]
  set rootid [wviewer::browser_root_id $rows]
  # --- TWO-PANE item 15: THE SECOND ROW THAT IS BORN OPEN --------------------
  #
  # M11 opens the design root, or the whole tree renders as one line. Under R7
  # that root is a DB HEADER's child, so opening it alone leaves R4's selected
  # node inside a collapsed parent where nobody can see it — and `see`, which
  # would scroll to it, is forbidden here (spec §4.2, BW53). So the root's own
  # parent is born open too, and ONLY the current DB's: a foreign header stays
  # collapsed (BD70b's third leg).
  #
  # ⚠⚠ "BORN" IS THE WHOLE RULE, AND IT REPLACES `$first` RATHER THAN JOINING
  # IT. `$first` meant "the tree was empty", which is FALSE on the populate that
  # matters most: ticking the All-DBs box re-shapes an already-drawn tree, so
  # under `$first` the header and root would arrive collapsed and R4's selection
  # would be invisible on the one gesture that creates it. "Newly born" — the id
  # was not in the tree a moment ago — is a strict superset of `$first` (nothing
  # existed, so everything is newly born) and leaves item 10's carry-over
  # untouched: a row that WAS there keeps whatever the user did to it.
  #
  # That is also R5. "The tree never auto-opens on a search" is what a rule of
  # "open the current header every populate" would break — every keystroke would
  # re-expand a header the user had just collapsed. BD69 is that check.
  set rootpar {}
  foreach r $nodes {
    if {[dict get $r id] eq $rootid} { set rootpar [dict get $r parent] ; break }
  }
  foreach r $nodes {
    set id [dict get $r id]
    set op 0
    if {[lsearch -exact $wasopen $id] >= 0} {
      set op 1
    } elseif {[lsearch -exact $existed $id] < 0 &&
              ($id eq $rootid ||
               ($rootpar ne {} && $id eq $rootpar))} {
      set op 1
    }
    $tv insert [dict get $r parent] end -id $id \
      -text [dict get $r text] -open $op
  }
  set want {}
  foreach id $prev {
    if {![catch {$tv exists $id} ex] && $ex} { set want $id ; break }
  }
  if {$want eq {} && $rootid ne {}} {
    if {![catch {$tv exists $rootid} ex] && $ex} { set want $rootid }
  }
  if {$want ne {}} { catch {$tv selection set [list $want]} }
  return [llength $nodes]
}

# The two searchbar consumers. `args` swallows the bar's
# `<pat> <syn> <case> <type>` AND IS NEVER READ — see browser_match's ⚠.
proc wviewer::browser_search_cb {token args} {
  wviewer::browser_refresh $token
  return
}
proc wviewer::browser_filter_cb {token args} {
  wviewer::browser_refresh $token
  return
}

# --- item 9: the three plot gestures (ViVA §3.4) ------------------------------
# double-click, middle-click, and the Plot toolbar button. ALL THREE converge on
# `wviewer::plot_signals`, which is where item 7's destination policy lives
# (ruling 24: `plot_dest` is THE accessor and nothing re-implements it). Nothing
# below reads plot_dest, plan_plot or the layout.
#
# ⚠ DECLARED LIMIT, INHERITED NOT INTRODUCED (ruling 24): under MULTI-plot a
# destination of `Replace` really Appends, because plan_plot emits no clear key
# there. A browser gesture offering Replace in multi mode is therefore offering
# Append. Surfaced in receipts/09_receipt.md; not item 9's to fix.

# Row ids -> {full raw name, database} -> plot_signals. Returns the number of
# signals plotted, 0 for a refused/empty gesture (which SPEAKS rather than
# sitting silent). Picks are deduplicated but keep ROW ORDER, so a selection
# spanning a group and one of its leaves plots that leaf once.
#
# ⚠⚠ THE DEDUPE IS ON {name, database}, NOT ON THE NAME (DEFECT 2, 2026-08-09).
# `TOP.m.sig` in blockA.vcd and `TOP.m.sig` in blockB.vcd are two different
# waveforms; deduping on the bare name silently collapsed them to one trace —
# blockA's, because `resolve_signal_db` returns the lowest-index match — however
# many rows the user had selected. The database comes from the ROW ID the user
# actually clicked (`browser_leaf_specs`), and is carried all the way into
# `add_trace`, so the trace plotted is the trace pointed at.
#
# `destover` (item 10) is handed straight to plot_signals and read NOWHERE here:
# the one-shot override is plot_signals' business, and BT06's "nothing in the
# browser re-reads plot_dest / plan_plot / dest_prepare" stays literally true.
proc wviewer::browser_plot_ids {token ids {destover {}}} {
  variable windows
  variable browserrows
  if {![dict exists $windows $token]} { return 0 }
  if {![info exists browserrows($token)]} { return 0 }
  set rows $browserrows($token)
  set names {}
  set dbs {}
  set seen {}
  foreach id $ids {
    foreach s [wviewer::browser_leaf_specs $rows $id] {
      if {[lsearch -exact $seen $s] >= 0} { continue }
      lappend seen $s
      lappend names [lindex $s 0]
      lappend dbs   [lindex $s 1]
    }
  }
  if {![llength $names]} {
    wviewer::echo {signal browser: nothing selected to plot} error
    return 0
  }
  set errs {}
  wviewer::plot_dbs_arm $token $dbs
  set rc [catch {wviewer::plot_signals $token $names {} $destover} errs]
  wviewer::plot_dbs_take $token          ;# no-op after a real call; clears after a stub
  if {$rc} {
    wviewer::echo "signal browser: $errs" error
    return 0
  }
  foreach e $errs {
    wviewer::echo "signal browser: [lindex $e 0]: [lindex $e 1]" error
  }
  return [llength $names]
}

# The Plot toolbar button: whatever is selected, in row order.
proc wviewer::browser_plot_selection {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return 0 }
  set sel {}
  catch {set sel [$tv selection]}
  return [wviewer::browser_plot_ids $token $sel]
}

# The double-click and middle-click bodies. `groups` 1 = a group row plots its
# leaves (MMB), 0 = a group row plots NOTHING (double-click, where ttk's own
# expand/collapse owns the gesture).
#
# ⚠ SELECTION-INDEPENDENT BY DESIGN. The row comes from `identify row %x %y`,
# not from `$tv selection`, because `event generate <Double-Button-1>` does not
# reliably set the selection first — a handler that read the selection would
# make the gesture untestable AND would surprise a user who double-clicked a row
# other than the selected one. When the clicked row IS in the selection the
# WHOLE selection plots (the ViVA behaviour); otherwise just that row.
proc wviewer::browser_plot_at {token W x y {groups 1}} {
  variable windows
  variable browserrows
  if {![dict exists $windows $token]} { return 0 }
  if {[catch {winfo exists $W} e] || !$e} { return 0 }
  set row {}
  catch {set row [$W identify row $x $y]}
  if {$row eq {}} { return 0 }
  set sel {}
  catch {set sel [$W selection]}
  if {[lsearch -exact $sel $row] >= 0} { set ids $sel } else { set ids [list $row] }
  if {!$groups && [info exists browserrows($token)]} {
    set keep {}
    foreach id $ids {
      if {[wviewer::browser_kind $browserrows($token) $id] eq {group}} { continue }
      lappend keep $id
    }
    if {![llength $keep]} { return 0 }
    set ids $keep
  }
  return [wviewer::browser_plot_ids $token $ids]
}

# --- item 10: the RMB context menu on a browser row ---------------------------
# Shape borrowed WHOLE from the trace/strip menus (item 7/8): a fail-closed
# GATE, a BUILD that is redone on every post so the entries carry THIS click's
# ids, a POST that returns 1/0, and an UNPOST that is idempotent.
#
# ⚠ WHAT KEEPS THE CANVAS OUT, MEASURED RATHER THAN ASSUMED (PLAN wording vs.
# reality). The PLAN asked for "the Tcl-only Button3 swallow that issue 0178
# established for the legend". That swallow is real (wviewer::btn3_filter) but it
# does not transfer to this surface and NOTHING here needs it: the tree's
# bindtags are {<tv> Treeview <top> all}; ttk's Treeview class binds no Button-3
# at all; `bind all <Button-3>` is empty; the viewer toplevel carries only
# FocusIn/Destroy; and the CANVAS is not in the chain (set_bindings binds
# win_path, not the toplevel). So the `break` on the binding below is DEFENCE IN
# DEPTH against a future toplevel- or all-level Button-3, and is NOT what keeps
# xschem's canvas RMB from firing. BM35 pins the bindtag structure and BM42
# pins the behaviour with a positive AND a negative control; BM01 pins only the
# `break` itself, and is named to say exactly that.

# THE GATE: the row ids an RMB at tree pixel (x,y) of `W` acts on, or {}.
# Fails closed at every rung, like trace_menu_pick — including RMB on BLANK tree
# space below the last row, which posts NOTHING rather than a menu of dead
# entries.
#
# Item 9's rule VERBATIM (browser_plot_at): the clicked row when it is not in the
# selection, the WHOLE selection when it is. And like item 9's gestures this
# NEVER MUTATES the selection — a right-click that silently re-selected would
# make "Plot" mean something different from what the user is looking at.
#
# ⚠ GROUPS: an RMB on a group DOES post and DOES act on its leaves, i.e. the
# `groups`-1 semantics of MMB and the Plot button, NOT the double-click's
# refusal. That refusal (item 9's D3) exists solely to yield the double-click
# gesture to ttk's expand/collapse; ttk owns no Button-3, so there is nothing to
# yield here. Deliberate, and pinned by BM27.
proc wviewer::browser_menu_ids {token W x y} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  if {[catch {winfo exists $W} e] || !$e} { return {} }
  set row {}
  catch {set row [$W identify row $x $y]}
  if {$row eq {}} { return {} }
  set sel {}
  catch {set sel [$W selection]}
  if {[lsearch -exact $sel $row] >= 0} { return $sel }
  return [list $row]
}

# Row ids -> the full raw names the menu acts on, deduplicated, in ROW ORDER.
#
# ⚠ "ROW ORDER" IS RAW-FILE ORDER (item 9's declared limit D7), which is not the
# tree's visual top-to-bottom order once ttk has re-parented a late arrival under
# its group. A multi-row menu target therefore acts in raw order. Same accessor,
# same order, as browser_plot_ids — they must not be able to disagree about what
# "these rows" means. An unknown id contributes nothing and NEVER throws.
proc wviewer::browser_menu_names {token ids} {
  variable browserrows
  if {![info exists browserrows($token)]} { return {} }
  set rows $browserrows($token)
  set names {}
  foreach id $ids {
    foreach n [wviewer::browser_leaf_names $rows $id] {
      if {[lsearch -exact $names $n] < 0} { lappend names $n }
    }
  }
  return $names
}

# Build (do not post) the menu for `ids`. Returns the widget path, or {} when
# there is no window, no name behind the ids, or Tk refused the widget.
#
# REBUILT ON EVERY POST, trace_menu_build's rule: every -command below closes
# over THIS click's ids, and a stale entry would act on the previous click's
# rows. The header is a DISABLED entry naming what the gate picked, so the user
# can see which rows the menu is about before invoking anything.
#
# ⚠ `Descend to here` is item 11's RESERVED SLOT: disabled, with NO -command, at
# the bottom. Reserving it here is why item 11 flips `-state`/`-command` only and
# never re-touches menu construction. BM25 pins all three properties.
#
# DEVIATION FROM THE PLAN, recorded: the PLAN spells the copy entry `Copy name`
# unconditionally. A fixed singular label over a 3-row selection is exactly the
# ruling-17 defect (a name that overstates what it does), so the label is
# DYNAMIC — `Copy name` / `Copy names (N)`, matching the header.
proc wviewer::browser_menu_build {token ids} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set names [wviewer::browser_menu_names $token $ids]
  if {![llength $names]} { return {} }
  set m [wviewer::ctx_menu_widget $token wvbrowsermenu]
  if {$m eq {}} { return {} }
  set n [llength $names]
  $m add command -state disabled \
    -label [expr {$n == 1 ? [lindex $names 0] : "$n signals"}]
  $m add separator
  # the WINDOW's policy, spelled out — a `Plot` that silently means `New Tab`
  # is the same defect as an unlabelled Replace under multi
  $m add command \
    -label "Plot ([wviewer::dest_menu_label $token [wviewer::plot_dest $token]])" \
    -command [list wviewer::browser_plot_ids $token $ids]
  # the ONE-SHOT override. Entries come from dest_labels (the combobox's own
  # source), never from literals, so the cascade and the Add Trace dropdown
  # cannot drift; and each -command carries the CODE, never the label.
  set sub [wviewer::ctx_menu_child $m dest]
  if {$sub ne {}} {
    foreach lab [wviewer::dest_labels] {
      set code [wviewer::dest_norm $lab]
      $sub add command -label [wviewer::dest_menu_label $token $code] \
        -command [list wviewer::browser_plot_ids $token $ids $code]
    }
  }
  # added even when the submenu could not be minted, so the entry INDICES are a
  # fixed table (BM23 asserts them by index) rather than a function of Tk's mood
  $m add cascade -label {Plot to} -menu $sub
  $m add command -label {Send to Add Trace...} \
    -command [list wviewer::browser_send_to_add_trace $token $ids]
  $m add command -command [list wviewer::browser_copy_names $token $ids] \
    -label [expr {$n == 1 ? {Copy name} : "Copy names ($n)"}]
  $m add separator
  # item 11 CONSUMES the reservation: state + command only, menu construction
  # otherwise untouched (which is what the reservation bought). LIVE when every
  # picked row agrees on ONE hierarchy path; still DISABLED with no command when
  # they disagree — browser_target_path's declared multi-row rule, surfaced here
  # rather than silently first-winning.
  set tp [wviewer::browser_target_path $token $ids]
  if {[lindex $tp 0] eq {ok}} {
    $m add command -label {Descend to here} \
      -command [list wviewer::browser_descend_to $token $ids]
  } else {
    $m add command -label {Descend to here} -state disabled
  }
  return $m
}

# Post the menu for an RMB at tree pixel (x,y), at ROOT pixel (rx,ry) — the
# event's %X/%Y. Returns 1 when Tk posted it, 0 when the gate refused or Tk
# could not.
#
# ⚠ TOTAL BY CONSTRUCTION. This rides a Tk binding, and a throw inside a binding
# pops bgerror — MODAL under X, which HANGS a headless run. Every rung is
# guarded and every refusal is a `return 0`. Note the guards are `catch {set ...}`
# and not one big `catch` around a body containing `return`: a `return` inside a
# catch script is CAUGHT (TCL_RETURN), so that shape would silently fall through
# to the post.
proc wviewer::browser_menu_post {token W x y {rx -1} {ry -1}} {
  set ids {}
  catch {set ids [wviewer::browser_menu_ids $token $W $x $y]}
  if {![llength $ids]} { return 0 }
  set m {}
  catch {set m [wviewer::browser_menu_build $token $ids]}
  if {$m eq {}} { return 0 }
  set r 0
  catch {set r [wviewer::ctx_menu_popup $W $m $x $y $rx $ry]}
  return $r
}

# Take the browser menu down and drop tk_popup's global grab. Idempotent.
proc wviewer::browser_menu_unpost {token} {
  return [wviewer::ctx_menu_drop $token wvbrowsermenu]
}

# `Copy name(s)`: the raw names, newline-joined, on the X CLIPBOARD (not the
# PRIMARY selection — a menu entry called Copy means Ctrl-V). Returns the count.
#
# Feedback goes to the sidebar's own status line and NOT through wviewer::echo:
# echo writes an action-log `-result` line, and a clipboard copy is not a
# replayable edit. The count is restored by the next browser_refresh.
#
# ⚠⚠ `::clipboard` IS FULLY QUALIFIED AND MUST STAY THAT WAY — MEASURED, not
# stylistic. This namespace ALREADY has a `wviewer::clipboard` (the trace
# clipboard's test seam, ~4500 lines below), which takes NO arguments; Tcl
# resolves an unqualified command in the enclosing namespace FIRST, so a bare
# `clipboard clear -displayof $top` calls THAT, throws "called with too many
# arguments", is swallowed by the catch below, and this proc silently returns 0
# with nothing copied and no message. That is exactly what the first cut did,
# and only BM33's real `clipboard get` saw it.
proc wviewer::browser_copy_names {token ids} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set names [wviewer::browser_menu_names $token $ids]
  if {![llength $names]} { return 0 }
  set top [dict get $windows $token top]
  if {[catch {
    ::clipboard clear -displayof $top
    ::clipboard append -displayof $top [join $names "\n"]
  }]} { return 0 }
  set n [llength $names]
  catch {wviewer::browser_status $token \
           "copied $n name[expr {$n == 1 ? {} : {s}}]"}
  return $n
}

# `Send to Add Trace...`: open the modeless Add Trace dialog (items 5/6) with the
# name prefilled into its Expression entry. Returns 1/0, never throws.
#
# ⚠ DECLARED LIMIT: with a MULTI-ROW target only the FIRST name is prefilled.
# The Expression entry holds ONE expression — that is the point of it, since the
# whole reason to route a name through this dialog is to edit it into an
# expression or give it a name. A batch goes through the dialog's own
# multi-select listbox (item 6) or through Plot. Asserted AS a limit (BM45),
# not hidden.
proc wviewer::browser_send_to_add_trace {token ids} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set names [wviewer::browser_menu_names $token $ids]
  if {![llength $names]} { return 0 }
  set w {}
  if {[catch {wviewer::add_trace_dialog $token} w]} { return 0 }
  if {$w eq {}} { return 0 }
  if {[catch {winfo exists $w.expr} e] || !$e} { return 0 }
  catch {
    $w.expr delete 0 end
    $w.expr insert end [lindex $names 0]
    focus $w.expr
  }
  return 1
}

# =============================================================================
# item 11: HIERARCHY SYNC, browser -> schematic ("Descend to here")
# doc/claude/signal_browser_batch/PLAN.md item 11, spec
# doc/claude/specs/waveform_viewer.md §"hierarchy sync".
#
# The user picks a row in the Signal Browser and the ASE-L session's DESIGN
# window ends up at that point in the hierarchy — raised, activated, and rolled
# back to exactly where it started if any step of the walk fails.
#
# ⚠⚠ THE PIVOT IS `xschem get sim_sch_path`, NEVER `xschem get sch_path`
# (settled decision 10). MEASURED on tests/headless/fixtures/wvhier, currsch 2,
# sch_path `.X1.X2.`:
#     raw_level 0 -> sim_sch_path `X1.X2.`
#     raw_level 1 -> sim_sch_path `X2.`
#     raw_level 2 -> sim_sch_path ``
# i.e. sim_sch_path is measured from the level where the raw was LOADED, which
# is the same origin the raw's own signal names use — so `v(x1.x2.net5)`'s path
# `x1.x2` and sim_sch_path are in the same coordinate system and sch_path is
# not. With NO raw loaded `sch_waves_loaded()` is -1, the skip loop never runs
# and the two getters agree byte for byte; that is why the divergence can only
# be seen (and only be sabotage-tested) with a raw actually read. Hence
# hier_origin_ok below.
#
# THE FIVE PLAN DEFECTS THIS BLOCK REPAIRS, all measured (receipts/11_receipt.md):
#  1. `sim_sch_path` carries a TRAILING DOT and is EMPTY at the sim root. The
#     PLAN's algorithm compares it to a dotted path with neither. hier_split.
#  2. Exact-first + case-insensitive-retry is NOT sufficient on its own: a
#     lowercase target `x1.x2` legitimately lands on `x1.X2`, and a byte-exact
#     final verify then rejects its own correct result and rolls back. The
#     verify must be case-insensitive. hier_same.
#  3. `descend -inst` returns the STRING `0` WITHOUT THROWING for a
#     non-subcircuit instance (measured on `V9`) or a raised semaphore, so
#     `catch` alone sees success. Every step is confirmed by READBACK.
#  4. `go_back` returns void and returns WITHOUT ascending on a Cancel at the
#     save prompt (actions.c) — again only the readback is truth.
#  5. `descend_schematic()` extends `sch_path` BEFORE `load_schematic()`, so a
#     failed load leaves the tree one level deep while returning 0. The
#     rollback is therefore by READBACK of where we actually are, never by
#     counting the steps we thought we took.
# =============================================================================

# --- A1: the PURE planners (no xschem, no Tk) --------------------------------

# A hierarchy path string -> its segment list. THE TRAILING-DOT NORMALISER:
# `xschem get sim_sch_path` answers `x1.x2.`, `x1.` and `` (the sim root), and
# the PLAN's algorithm compares those directly against a dotted browser path
# that has no trailing dot. `x1.x2.` -> {x1 x2}; `` -> {}.
proc wviewer::hier_split {p} {
  set p [string trimright $p .]
  if {$p eq {}} { return {} }
  return [split $p .]
}

# Length of the EXACT (byte) common prefix of two segment lists.
#
# ⚠ DELIBERATELY NOT CASE-INSENSITIVE, and that is the whole reason "an exact
# hit always wins" survives a design carrying BOTH `x1` and `X1` (which the
# wvhier fixture does): from `X1.X2`, a target of `x1` must share NO prefix and
# so must ascend twice and descend into the OTHER instance. A -nocase prefix
# here would keep it inside `X1` and land on the wrong subtree while reporting
# success.
proc wviewer::hier_common {a b} {
  set n 0
  set lim [llength $a]
  if {[llength $b] < $lim} { set lim [llength $b] }
  while {$n < $lim && [lindex $a $n] eq [lindex $b $n]} { incr n }
  return $n
}

# {<levels to ascend> <segments to descend>} to get from `cur` to `target`.
# {0 {}} when already there. PURE.
proc wviewer::hier_plan {cur target} {
  set c [wviewer::hier_common $cur $target]
  return [list [expr {[llength $cur] - $c}] [lrange $target $c end]]
}

# THE FINAL-VERIFY COMPARATOR, and it is `-nocase` for a MEASURED reason rather
# than a stylistic one. ngspice lowercases: the raw carries `x1.x2` while the
# schematic instance is `X2`, and `get_instance()` (scheduler.c) is a plain
# strcmp — so a correct walk of the lowercase target legitimately lands on the
# schematic's own spelling `x1.X2`. A byte-exact verify rejects that correct
# result and rolls the user back for no reason. Reproduced before this line was
# written: `CASE hgo x1.x2 -> {err {verify failed} {}}`.
proc wviewer::hier_same {a b} {
  return [string equal -nocase [join $a .] [join $b .]]
}

# --- A2: the CONTEXT-LEVEL walk (xschem verbs, no Tk) ------------------------

# Where the CURRENT xschem context sits, as a segment list. THE ONLY PIVOT READ
# IN THE ITEM, and it never throws.
#
# ⚠ `xschem get sch_path` IS FORBIDDEN HERE (settled decision 10). MEASURED at
# raw_level 1, currsch 2: sim_sch_path `x2.` vs sch_path `.X1.X2.` — using
# sch_path puts the sync one or more levels off, silently and plausibly.
proc wviewer::hier_now {} {
  set p {}
  catch {set p [xschem get sim_sch_path]}
  return [wviewer::hier_split $p]
}

# One path segment -> the SCHEMATIC's own spelling of that instance name, or {}
# when nothing at this level matches. The sentinel `VECTOR` for a bracketed
# segment (see hier_walk's refusal and issue 0212).
#
# EXACT WINS, ALWAYS, and the case-insensitive candidate is only returned when
# the whole pass found no exact hit — so a level carrying both `x1` and `X1`
# resolves each of them to itself. That ordering is the reason hier_common is
# byte-exact too; the two must agree about what "the same segment" means.
#
# ⚠ THE SCAN IS BY INDEX, never `xschem getprop instance <name> name`, and that
# is measured: `get_instance()` (scheduler.c) treats an ALL-DIGIT argument as an
# INDEX, so a by-name lookup of a numeric segment would silently answer with
# some other instance. Declared limit, not guarded: a raw file's hierarchy path
# segments are SPICE instance names, which cannot be all digits, so the case is
# unreachable from the browser.
proc wviewer::hier_resolve {seg} {
  if {[string first {[} $seg] >= 0} { return VECTOR }
  set n 0
  catch {set n [xschem get instances]}
  if {![string is integer -strict $n]} { return {} }
  set ci {}
  for {set i 0} {$i < $n} {incr i} {
    set nm {}
    if {[catch {xschem getprop instance $i name} nm]} { continue }
    if {$nm eq $seg} { return $nm }
    if {$ci eq {} && [string equal -nocase $nm $seg]} { set ci $nm }
  }
  return $ci
}

# THE ITEM. Walk the CURRENT context to `target` (a dotted, sim-root-relative
# instance path; {} = the sim root itself). Returns
#     {ok <landed path>}            moved, verified
#     {ok already <path>}           was already there, NOTHING was touched
#     {err <reason> <path>}         refused; `path` is where we actually are
# and NEVER throws.
#
# ALGORITHM, written here so nobody re-derives it wrong:
#  0. start = hier_now. If start and the target are BYTE-identical, return
#     `already` without touching anything — no selection change, no redraw.
#     (A case-MISMATCHED already-at-target deliberately re-walks and lands
#     correctly, reporting the schematic's spelling. Declared limit.)
#  1. hier_plan -> {nup segs}.
#  2. ASCEND nup times with `xschem go_back`, RE-READING hier_now after each and
#     requiring the depth to have DECREASED. `go_back` returns void, is a silent
#     no-op at semaphore != 0, and returns WITHOUT ascending when the user
#     cancels the save prompt — the readback is the only truth. Default what=1
#     is used deliberately: the PLAN forbids bypassing the existing guard, and
#     on a rollback the levels we just descended into are unmodified so no
#     prompt can fire.
#  3. DESCEND each remaining segment: hier_resolve, then `xschem descend -inst`,
#     requiring BOTH the result string `1` AND hier_now to have GROWN. Measured:
#     `descend -inst V9` (a non-subcircuit) returns the STRING `0` with no throw
#     and no movement, so `catch` alone sees nothing.
#  4. VERIFY hier_same (case-insensitive, see its header).
#  5. ANY failure and `rollback` -> re-walk to `start` with rollback OFF (the
#     walk is idempotent, so the rollback IS the same primitive), then report.
#     BY READBACK, never by counting: descend_schematic() extends sch_path
#     BEFORE load_schematic(), so a failed load leaves the tree one level deep
#     while returning 0.
#
# ⚠ A SUCCESSFUL WALK CLEARS THE SELECTION at every level it traverses, because
# both `descend -inst` and `go_back` call unselect_all(1) in C. The `already`
# path does not. Declared, not hidden.
proc wviewer::hier_walk {target {rollback 1}} {
  set tgt   [wviewer::hier_split $target]
  set start [wviewer::hier_now]
  if {[join $start .] eq [join $tgt .]} {
    return [list ok already [join $start .]]
  }
  lassign [wviewer::hier_plan $start $tgt] nup segs
  set problem {}
  for {set i 0} {$i < $nup} {incr i} {
    set before [llength [wviewer::hier_now]]
    catch {xschem go_back}
    if {[llength [wviewer::hier_now]] >= $before} {
      set problem "could not ascend from [join [wviewer::hier_now] .]"
      break
    }
  }
  if {$problem eq {}} {
    foreach seg $segs {
      set real [wviewer::hier_resolve $seg]
      if {$real eq {VECTOR}} {
        set problem "vector instance '$seg' cannot be addressed (issue 0212)"
        break
      }
      if {$real eq {}} { set problem "no instance '$seg'" ; break }
      set before [llength [wviewer::hier_now]]
      set r {}
      catch {xschem descend -inst $real} r
      if {$r ne {1} || [llength [wviewer::hier_now]] <= $before} {
        set problem "descend refused at '$real'"
        break
      }
    }
  }
  set now [wviewer::hier_now]
  if {$problem eq {} && ![wviewer::hier_same $now $tgt]} {
    set problem "verify failed at [join $now .]"
  }
  if {$problem ne {}} {
    if {$rollback} { wviewer::hier_walk [join $start .] 0 }
    return [list err $problem [join [wviewer::hier_now] .]]
  }
  return [list ok [join $now .]]
}

# --- A3: THE ORIGIN GUARD ----------------------------------------------------

# 1 iff `sim_sch_path` in the CURRENT context really is measured from the same
# origin the browser's paths are, else 0 and the caller REFUSES rather than
# guesses.
#
# ⚠ THIS IS THE ITEM'S ONLY CLAIM A READBACK CANNOT CHECK. ASE reads the raw
# into the VIEWER context only (the `raw read` sites in this file), so in the
# DESIGN window `sch_waves_loaded()` is -1 and `sim_sch_path` degrades to
# `sch_path` minus its leading dot. That degraded getter is CORRECT exactly when
# the design window's top IS the session's design — and when it is not, the
# pivot and the verify share the same wrong origin, so the walk would land N
# levels off and report success. Only this guard can see it.
#
# NEITHER BRANCH READS `sch_path` (settled decision 10).
proc wviewer::hier_origin_ok {token} {
  set lv -1
  catch {set lv [xschem raw loaded]}
  if {[string is integer -strict $lv] && $lv >= 0} { return 1 }
  set b 0
  catch {set b [ase::ui::sod_base_level $token]}
  if {![string is integer -strict $b]} { return 1 }
  return [expr {$b == 0 ? 1 : 0}]
}

# --- A4: the Tk entry layer --------------------------------------------------

# A browser ROW ID -> the dotted instance path it names. PURE.
#
# ⚠⚠ THIS PROC EXISTS BECAUSE THERE WERE TWO IDENTICAL COPIES OF IT AND THEY
# WERE BOTH WRONG (spec §4.3). `browser_target_path` and `browser_show_path`
# each did `[string range $id 2 end]`, which strips the `g:`/`s:` namespace but
# NOT the All-DBs `d:<N>|` prefix that `browser_rows_reparent` adds — so
# `d:0|g:x1.x2` decoded to `0|g:x1.x2`, "Descend to here" was ENABLED on foreign
# rows, and it fired a garbage instance path. Six characters of string
# arithmetic earn their own proc here for exactly one reason: two copies drifted
# once and would drift again.
#
# `g:` and `d:0|g:` both decode to `{}` — the design root, i.e. the legitimate
# sim-root ascend, which is what makes item 2's choice of `g:` for the root id
# free of any change to the callers.
#
# --- §F item F6 (issue 0308): THE DATABASE HALF IS AN ANSWER, NOT LITTER -----
#
# ⚠⚠ THE DECODE ANSWERS BOTH HALVES, `{<registry idx or {}> <dotted path>}`, AND
# THAT IS THE WHOLE OF ISSUE 0308's FIRST STEP. Stripping `d:N|` and returning
# only the path throws away the one fact that says WHICH INVENTORY the path is
# to be looked up in; every caller then looked it up in the only one there was —
# the current database's — and the browser answered confidently with the current
# database's namesakes for a node that came from somewhere else. MEASURED on two
# databases that each carry `x1`: the foreign scope listed the CURRENT raw's
# `v(x1.fromraw)`. Absent would have been bad; wrong was worse.
#
# `browser_id_path` is kept as the ONE-LINE PROJECTION rather than being
# re-signatured, and deliberately: `browser_target_path` and `browser_show_path`
# each call it exactly once and `TP44` counts those two call sites as a frozen
# 1/1 (it is the check that exists because those two sites once held two copies
# of the string arithmetic and both were wrong). A caller that needs the database
# asks for the pair; a caller that does not is untouched.
proc wviewer::browser_id_split {id} {
  set db {}
  if {[regexp {^d:([0-9]+)\|} $id -> n]} {
    set db $n
    regsub {^d:[0-9]+\|} $id {} id
  }
  return [list $db [string range $id 2 end]]
}
proc wviewer::browser_id_path {id} {
  return [lindex [wviewer::browser_id_split $id] 1]
}

# The CURRENT DB's design-root id: `g:` normally, `d:0|g:` when All-DBs has put
# the current DB under a header (item 15). `{}` when the row list has no root at
# all — every shipped caller today — and that absence is an ANSWER, so a caller
# can tell "there is no root" from "the root is `g:`".
#
# The current DB's rows are always FIRST (browser_rows_multi's ⚠), so the first
# match in row order is the current DB's. A DB HEADER (`d:0`, no `|g:`) is not a
# design root and must never be mistaken for one — its text is a file name, not
# an instance.
proc wviewer::browser_root_id {rows} {
  foreach r $rows {
    if {[wviewer::dget $r kind {}] ne {group}} { continue }
    set id [wviewer::dget $r id {}]
    if {$id eq {g:} || [regexp {^d:[0-9]+\|g:$} $id]} { return $id }
  }
  return {}
}

# Browser row ids -> {ok <dotted path>} / {err <message>}. A group id `g:x1.x2`
# IS the dotted instance path (item 9's tree groups one node per dot segment,
# settled decision 14); a leaf id resolves through the ROW's stored name — not
# through the id — because browser_rows disambiguates a duplicate id with a
# `#N` suffix that is not part of the raw name. A top-level signal yields
# `{ok {}}`, which is a legitimate ascend-only sync to the sim root.
#
# ⚠ THE MULTI-ROW RULE, chosen against a silent first-wins (ruling 17): a set of
# rows resolves ONLY when every row yields the SAME path. A disagreeing set is
# an `err`, and the menu entry stays DISABLED. Declared, not hidden.
proc wviewer::browser_target_path {token ids} {
  variable browserrows
  if {![info exists browserrows($token)]} {
    return [list err {the Signal Browser has nothing to descend to}]
  }
  if {![llength $ids]} {
    return [list err {select a row in the Signal Browser first}]
  }
  set rows $browserrows($token)
  set path {}
  set first 1
  foreach id $ids {
    set row {}
    foreach r $rows {
      if {[wviewer::dget $r id {}] eq $id} { set row $r ; break }
    }
    if {$row eq {}} { return [list err "unknown row '$id'"] }
    if {[wviewer::dget $row kind {}] eq {group}} {
      set p [wviewer::browser_id_path $id]
    } else {
      # ⚠⚠ THE LEAF IS SPLIT WITH ITS OWN DATABASE'S GRAMMAR IN HAND, and this
      # is the leg that keeps a GROUP row and a LEAF ROW UNDER IT answering the
      # SAME path. `browser_rows` builds the group id from the entry's path, so
      # once RULING F4 stopped declassing digital names the group said `m.sub`
      # while a one-argument split of its own child still said `sub` — and the
      # multi-row rule below then read a scope and its own wire as being in
      # different parts of the hierarchy and REFUSED, while the wire alone
      # descended to a node the tree never showed. MEASURED on `m.sub.sig`:
      # group `ok m.sub`, leaf `ok sub`, both together `err`.
      set p [lindex [wviewer::sig_split [wviewer::dget $row name {}] \
                       [wviewer::browser_id_type $token $id]] 0]
    }
    if {$first} { set path $p ; set first 0 } \
    elseif {$p ne $path} {
      return [list err {those rows are in different parts of the hierarchy}]
    }
  }
  return [list ok $path]
}

# THE COMMAND. Returns 1/0 and NEVER throws (it rides a menu entry and a key
# binding; a throw in either pops bgerror, which is modal under X).
#
# ⚠ EVERY RUNG ASSERTS ON THE WORLD, never on "the call returned without
# throwing" — the item-10 lesson (a bare `clipboard clear` resolved to this
# namespace's own zero-argument proc, threw, was swallowed by a catch, and the
# menu entry silently did nothing while every structural check stayed green).
# So: the context switch is confirmed by re-reading `current_win_path`, and the
# hierarchy move is confirmed by re-reading `sim_sch_path`.
#
# Context is LEFT ON THE DESIGN WINDOW on success, matching Direct Plot and
# `ase::ui::raise_window_entry`; the viewer's own later reads take their usual
# 0173 loan.
proc wviewer::browser_descend_to {token ids} {
  set r [wviewer::browser_target_path $token $ids]
  if {[lindex $r 0] ne {ok}} {
    catch {wviewer::browser_status $token [lindex $r 1]}
    return 0
  }
  set path [lindex $r 1]

  # 2. the session's design window: raise it (opening it if it is not open)
  set opened 0
  catch {set opened [ase::ui::design_window $token]}
  if {!$opened} {
    catch {wviewer::browser_status $token {could not reach the design window}}
    return 0
  }

  # 3. VERIFY THE CONTEXT FOLLOWED — PLAN step 3 / landmine 17, and it is real
  # work: ase::ui::raise_window_entry does a bare `xschem new_schematic switch`
  # with NO verify, and a switch under a raised semaphore silently no-ops. The
  # scan mirrors raise_design_editor's (current_name first, then the 7th
  # `xschem windows` field, which is the window's whole hierarchy stack, so a
  # window already DESCENDED into the design still matches — issue 0168).
  set dpath {} ; catch {set dpath [ase::ui::design_path $token]}
  set want {} ; set wtop {}
  if {$dpath ne {}} {
    catch {
      foreach e [xschem windows] {
        foreach s [concat [list [lindex $e 4]] [lindex $e 6]] {
          if {$s eq {}} continue
          if {[file normalize $s] eq $dpath} {
            set want [lindex $e 0] ; set wtop [lindex $e 1] ; break
          }
        }
        if {$want ne {}} break
      }
    }
  }
  set cur {} ; catch {set cur [xschem get current_win_path]}
  if {$want eq {} || $cur ne $want} {
    catch {wviewer::browser_status $token {could not reach the design window}}
    catch {wviewer::echo {signal browser: could not reach the design window} error}
    return 0
  }
  if {$wtop eq {}} { set wtop . }

  # 4. THE ORIGIN GUARD. Refuse, never guess — see hier_origin_ok.
  if {![wviewer::hier_origin_ok $token]} {
    set m {the design window is opened on an ancestor of this session's design; cannot map the browser path}
    catch {wviewer::browser_status $token $m}
    catch {wviewer::echo "signal browser: $m" error}
    return 0
  }

  # 5. the walk
  set res [wviewer::hier_walk $path]

  # 6. raise + activate, ALSO on the already-there path (the PLAN: "a no-op that
  # still raises the window, and says so"). raise_activate_toplevel is the WSLg
  # idiom — a bare deiconify/raise is a no-op there (issue 0054) — and it
  # no-ops entirely without ::has_x, which is why every raise assertion is
  # X-arm only.
  catch {raise_activate_toplevel $wtop}
  catch {focus $wtop}

  # 7. say what happened, both surfaces, never silently
  if {[lindex $res 0] ne {ok}} {
    set m "descend to '$path' failed: [lindex $res 1] (returned to [lindex $res 2])"
    catch {wviewer::browser_status $token $m}
    catch {wviewer::echo "signal browser: $m" error}
    return 0
  }
  if {[llength $res] == 3} {
    set where [lindex $res 2]
    set m "already at [expr {$where eq {} ? {the top level} : $where}]"
  } else {
    set where [lindex $res 1]
    set m "descended to [expr {$where eq {} ? {the top level} : $where}]"
  }
  catch {wviewer::browser_status $token $m}
  catch {wviewer::echo "signal browser: $m"}
  return 1
}

# The key/menubar target: the tree's CURRENT SELECTION (a menu entry and a key
# have no pointer position to resolve, unlike the RMB entry).
proc wviewer::browser_descend_here {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return 0 }
  set sel {}
  catch {set sel [$tv selection]}
  if {![llength $sel]} {
    catch {wviewer::browser_status $token {select a row in the Signal Browser first}}
    return 0
  }
  return [wviewer::browser_descend_to $token $sel]
}

# Bindtag shim. `%W` is the CANVAS when the key came through the `WaveViewer`
# tag and the TREEVIEW when it came through the tree's own binding, so both
# lookups are tried — the treeview's bindtags are {<tv> Treeview <top> all} and
# the canvas is NOT among them (measured, item 9 BT34 / item 10 BM35), which is
# exactly why a WaveViewer-only bind would be a key that never fires where the
# user actually is.
proc wviewer::browser_descend_at {W} {
  variable windows
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} {
    set tp {}
    catch {set tp [winfo toplevel $W]}
    if {$tp ne {}} {
      dict for {t rec} $windows {
        if {[dict exists $rec top] && [dict get $rec top] eq $tp} { set tok $t ; break }
      }
    }
  }
  if {$tok eq {}} { return 0 }
  return [wviewer::browser_descend_here $tok]
}

# =============================================================================
# item 12 — HIERARCHY SYNC, SCHEMATIC -> BROWSER ("Show in Signal Browser")
# doc/claude/signal_browser_batch/PLAN.md item 12, receipts/12_receipt.md.
#
# THE MIRROR of item 11. Item 11 turns a browser row into an xschem descend;
# item 12 turns the schematic's own hierarchy position into a browser node that
# is selected AND VISIBLE. The pivot is the same one settled decision 10 names —
# `xschem get sim_sch_path`, via item 11's `hier_now`/`hier_split`; NOTHING here
# reads `sch_path`, and nothing here writes a second normaliser.
#
# The entry point is `ase::show_in_browser_for_current` (src/ase.tcl), reached
# from the design window's Tools menu and Ctrl-Alt-V (TWO-PANE item 17, R10:
# the chord is a C action-registry row now, not the cadence-only rc bind it was).
# The three procs below are the
# viewer-side half: PURE match, Tk reveal, and the one command that sequences
# them and SPEAKS on every branch (settled decision 11 — neither direction ever
# fails silently).
# =============================================================================

# A segment list -> the DEEPEST browser GROUP row it reaches, plus HOW MANY
# segments matched. `{<id> <matched>}`; `{{} 0}` when the very first segment
# misses. PURE — no Tk, no xschem — which is what makes the deepest-ancestor
# fallback testable in the `--nogui` arm.
#
# ONE call answers BOTH questions the caller has ("is this exactly the node?"
# and "what is the deepest ancestor that does exist?"), so there is no second
# walk that could disagree with the first.
#
# ⚠ EXACT WINS WITHIN A LEVEL, `-nocase` IS THE FALLBACK — item 11's
# `hier_resolve` rule, one layer over, and it is a MEASURED necessity rather
# than politeness: ngspice lowercases, so the raw (and therefore the tree) says
# `x1.x2` while `sim_sch_path` reports the schematic's own `X1.X2`. Without the
# case-insensitive candidate this item finds nothing on any real raw. Keeping
# exact FIRST is what stops a design carrying both `x1` and `X1` from folding
# them together — the same reason `hier_common` is byte-exact.
#
# ⚠ GROUPS ONLY, DECLARED LIMIT. A leaf row is a SIGNAL, not an instance, so a
# path segment must never match one: `v(x1.out)` must not make `out` look like
# a descendable instance.
# ⚠ `start` (item 8) IS LOAD-BEARING, NOT DEFENSIVE. The walk below scans for a
# group whose `parent` is `$parent`, seeded `{}`. Once item 2's design root
# exists EVERY real instance hangs off `g:`, so a walk seeded `{}` dead-ends on
# the first segment and answers `{{} 0}` — item 12's whole "Show in Signal
# Browser" would stop working on every raw the moment the tree grew its root.
# The caller passes `[browser_root_id $rows]`, which answers `g:` normally and
# `d:0|g:` when All-DBs put the current DB under a header. The DEFAULT stays
# `{}` so every shipped caller and BX01-BX08 are unchanged.
proc wviewer::browser_node_for {rows segs {start {}}} {
  set parent $start
  set cur {}
  set matched 0
  foreach seg $segs {
    set exact {}
    set ci {}
    foreach r $rows {
      if {[wviewer::dget $r kind {}] ne {group}} { continue }
      if {[wviewer::dget $r parent {}] ne $parent} { continue }
      set t [wviewer::dget $r text {}]
      if {$t eq $seg} { set exact [wviewer::dget $r id {}] ; break }
      if {$ci eq {} && [string equal -nocase $t $seg]} {
        set ci [wviewer::dget $r id {}]
      }
    }
    set hit [expr {$exact ne {} ? $exact : $ci}]
    if {$hit eq {}} { break }
    set parent $hit
    set cur $hit
    incr matched
  }
  return [list $cur $matched]
}

# How many leading segments of `hier_now` must be dropped to turn the DESIGN
# window's position into a path measured from the ORIGIN the browser's own
# names use. PURE, and it is a separate proc precisely so the arithmetic is
# assertable without a loaded design.
#
#   `level`    — where the session's design sits in THIS window's hierarchy
#                stack (`ase::session_for_current`'s second element, issue 0168).
#   `rawlevel` — `xschem raw loaded` in the DESIGN context: -1 for the ordinary
#                case (ASE reads raws into the VIEWER context only), else the
#                stack level `sim_sch_path` is already measured from.
#
# ⚠ MEASURED IDENTITY, not reasoned: with no raw loaded `sim_sch_path` degrades
# to the window's whole path (settled decision 10's corollary — `sch_waves_
# loaded()` is -1 so the C skip loop never runs), so dropping `level` segments
# reproduces `ase::ui::sod_rel_path $level` exactly — WITHOUT reading sch_path,
# which decision 10 forbids this batch. Asserted as a value by BX49.
#
# A NEGATIVE answer means the raw was read BELOW the session's design: the two
# origins cannot be reconciled and the caller REFUSES rather than guessing.
proc wviewer::browser_origin_drop {level rawlevel} {
  if {![string is integer -strict $level] || $level < 0} { set level 0 }
  set base 0
  if {[string is integer -strict $rawlevel] && $rawlevel >= 0} {
    set base $rawlevel
  }
  return [expr {$level - $base}]
}

# Select row `id`, focus it, and make it VISIBLE. 1/0, NEVER throws (it rides a
# menu entry and a key; a throw pops bgerror, modal under X).
#
# ⚠ `$tv see $id` IS THE EXPANSION, and that is the fact this proc is shaped
# around. ttk's `see` sets EVERY ancestor's `-open` to true and then scrolls —
# so an explicit expand-ancestors loop here would be dead code no sabotage could
# reach, and "select without expanding" (the PLAN's sabotage (a)) is not a state
# this implementation can be put into by deletion. Deleting `see` itself is, and
# that is what the substituted sabotage (a) does.
#
# ⚠⚠ THE TARGET ITSELF IS LEFT CLOSED, AND TWO-PANE ITEM 13 IS WHERE THAT
# CHANGED. Opening the target is the one thing `see` does NOT do (it opens
# ancestors), and this proc used to do it by hand so that landing on `x1.x2`
# also showed what was inside it. Under the two-pane sidebar the LOWER PANE is
# the answer to "what is inside this node": the selection set above fires
# `<<TreeviewSelect>>`, the sea below redraws with this node's own signals, and
# force-opening the row as well would say the same thing twice in the pane that
# is now nodes only. So the reveal expands the CHAIN and stops.
#
# ⚠ THE RULING IS **R3**, NOT §4.2 — doc/claude/specs/waveform_signal_browser_
# two_pane.md §2.1 R3, "the lower pane shows the selected node's own-level
# signals only". §4.2 is a DIFFERENT ruling — who may reach `see`, and that a
# persisted open set beats it, which is the STATE-RESTORE path's business rather
# than this proc's — and it says nothing about the target's own row. An earlier
# revision of this comment cited §4.2 here and would have sent a later reader
# hunting for a rule that is not there.
#
# Re-adding the open reds BW77 and BW68 (test_wave_sigbrowser_panes.tcl), BW15
# (same file, the source claim) and BX31 (test_wave_sigbrowser_i12.tcl).
# ⚠⚠ BW77 IS THE ONE THAT MATTERS, and it was added by the item-13 FIXUP after a
# verifier found the hole: BW68 and BX31 both land on `g:x1.x2`, which is
# CHILDLESS, and on a childless row `-open` is stored but never RENDERED. A
# re-add guarded on `[llength [$tv children $id]] > 0` was therefore invisible to
# every check in the batch while restoring exactly the pre-item-13 behaviour in
# the only node class where a user can see it. BW77 reveals `g:x1`, which has
# children.
#
# ⚠ `$tv exists {}` IS TRUE (the root), so the empty id is refused explicitly —
# otherwise `selection set {}` would silently CLEAR the selection and report
# success. The sim-root case is `browser_show_path`'s `root` branch, which
# clears deliberately and says so.
proc wviewer::browser_reveal {token id} {
  variable windows
  if {$id eq {}} { return 0 }
  if {![dict exists $windows $token]} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return 0 }
  if {[catch {$tv exists $id} ex] || !$ex} { return 0 }
  set ok 1
  if {[catch {$tv selection set [list $id]}]} { set ok 0 }
  catch {$tv focus $id}
  catch {update idletasks}
  if {[catch {$tv see $id}]} { set ok 0 }
  return $ok
}

# THE COMMAND's viewer half. A dotted, browser-origin instance path -> the tree
# selection, scrolled into view. Returns, and NEVER throws:
#
#   {ok      <id> <path>}            exact node, selected and visible
#   {partial <id> <landed> <asked>}  deepest ancestor that exists (PLAN: "say so
#                                    and select the deepest ancestor")
#   {root    <asked>}                the sim root itself — selection CLEARED and
#                                    the tree scrolled home, which IS the answer
#   {err     <reason>}               nothing to show; the SELECTION IS LEFT
#                                    ALONE (decision 11's mirror: a failed sync
#                                    leaves the user where they were)
#
# Every branch writes the status line AND echoes, so the report exists whether
# the user is looking at the sidebar or at the CIW.
#
# ⚠ D6 AND THE RELOAD, decided deliberately (item 9: "the inventory is a
# SNAPSHOT taken when the sidebar is SHOWN"). A snapshot taken before the raw
# was read has no node for anything. So a MISS — and ONLY a miss — spends one
# `browser_refresh $token 1` and retries. A HIT never reloads, because
# `browser_populate` re-inserts every row `-open 1` and clears the selection: an
# unconditional reload would erase the very collapse state the user built and
# would make this item's own visibility claim untestable.
proc wviewer::browser_show_path {token path} {
  variable windows
  variable browsersigs
  variable browserrows
  # item 14: browserdbsigs is part of the SAME snapshot and therefore part of
  # the same improve-or-restore below — a failed sync that put browsersigs back
  # while leaving an emptied foreign inventory would silently switch All-DBs off.
  variable browserdbsigs
  # TWO-PANE item 18 (R12): the probe below derives the design-root LABEL the
  # same way browser_refresh does, from this window's own raw path.
  variable browserraw
  if {![dict exists $windows $token]} {
    return [wviewer::browser_say $token err {no waveform viewer window is open}]
  }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f.pw.tvf.tv} e] || !$e} {
    return [wviewer::browser_say $token err {the Signal Browser is not built}]
  }
  set tv $f.pw.tvf.tv
  # decision 13: browser state derives from the raw inventory, NEVER from the
  # rect model (0186 stays open, items 8+ route around it).
  if {![info exists browsersigs($token)] || ![llength $browsersigs($token)]} {
    catch {wviewer::browser_refresh $token 1}
  }
  if {![info exists browsersigs($token)] || ![llength $browsersigs($token)]} {
    return [wviewer::browser_say $token err \
      {no simulation data loaded - read a raw file first}]
  }
  set rows {}
  if {[info exists browserrows($token)]} { set rows $browserrows($token) }
  set segs [wviewer::hier_split $path]
  if {![llength $segs]} {
    # ⚠ TWO-PANE item 10 (R4): the sim root SELECTS the design root instead of
    # clearing. Clearing was the right answer while the tree's top level was a
    # forest of instances and there was no row that MEANT "the whole design";
    # now there is exactly such a row, and R4 forbids an empty selection. The
    # fallback to a bare clear is kept for a row list that has no root at all
    # (a legacy state, or All-DBs, where item 15 owns the per-DB roots).
    set rid [wviewer::browser_root_id $rows]
    if {$rid ne {} && ![catch {$tv exists $rid} rex] && $rex} {
      catch {$tv selection set [list $rid]}
      catch {$tv focus $rid}
    } else {
      catch {$tv selection set {}}
    }
    catch {$tv yview moveto 0}
    return [wviewer::browser_say $token root {} {} {}]
  }
  lassign [wviewer::browser_node_for $rows $segs \
             [wviewer::browser_root_id $rows]] id matched
  # --- TWO-PANE item 18 (R12): THE AUTO-UNHIDE --------------------------------
  #
  # ⚠⚠ A POSITIVE TEST, NOT AN ABSENCE, and that distinction IS the ruling.
  # "the node is missing, so tick the box" ticks it for a genuinely absent path
  # and for one the Search bar is hedging about — two states in which unhiding 84
  # nodes explains nothing and merely moves the user somewhere they did not ask
  # to go. The only question that justifies the tick is asked here: WOULD this
  # path resolve if device internals were shown?
  #
  # ⚠ THE PROBE IS PURE. It rebuilds the would-be model IN MEMORY through the
  # very procs the refresh uses (signal_entry -> the class filter -> the rows),
  # touches no widget and fires no refresh. So every shipped miss on an
  # inventory with no hidden device nodes answers "no" and runs the untouched
  # code below at the cost of one list walk; only a YES spends a refresh. That
  # is what keeps the seven shipped miss-arm checks in _i12/_i11 green.
  #
  # ⚠⚠ ONE DECISION POINT AND NO CONFIRM GUARD. The rejected shape is "tick,
  # refresh, re-resolve, untick if it failed": its guard puts the box back, so
  # forcing the decision to always-yes reds NOTHING and the positive test stops
  # being testable at all. MEASURED as well as reasoned — 0 of this corpus's 84
  # hidden nodes are revealed by the device box only when the source-currents box
  # is also on (45/129 either way), so the guard would be dead code no sabotage
  # could reach.
  #
  # ⚠ THE TICK GOES THROUGH THE CHECKBUTTON'S OWN -command — the path a user's
  # click takes (spec §7.4) — never through a direct refresh call. That is how it
  # INHERITS "a box toggle re-filters and never re-enters the engine" instead of
  # restating it, and it is why the auto-tick costs exactly ONE refresh.
  #
  # ⚠ IT MERGES INTO `$id`/`$matched` AND DECODES NOTHING. The shipped
  # `browser_id_path` at the tail is the ONE decode for every kind; a second call
  # here reds a frozen source oracle (test_wave_sigbrowser_2pane.tcl's TP44) that
  # no behavioural check in the batch can see.
  #
  # DECLARED LIMIT: the tick is kept only on a FULL resolution. A path whose
  # would-be model resolves DEEPER but still not fully leaves the box alone and
  # reports the shipped `partial` at the shallower landing — because the sentence
  # says "to reach <node>", which a partial makes a lie.
  #
  # ⚠⚠ THAT LIMIT IS PINNED, NOT MERELY DECLARED — `BK43` in
  # tests/headless/test_wave_sigbrowser_keys.tcl. It shipped declared-but-
  # unasserted in TWO-PANE item 18 and the fix-up closed the hole: relaxing the
  # `==` that guards the tick below into a `>` ("surely a deeper landing is
  # still an improvement") is a one-line edit that ticks the box, TRIPLES the tree
  # from 45 nodes to 129 and says nothing about it in the status line — measured
  # on `x1.x1.xm1.zznosuch`, which walks 2 of 4 segments hidden and 3 of 4 shown.
  # Before BK43 that edit red NOTHING in either arm. Do not relax it without
  # moving that check.
  set r12 0
  if {$matched < [llength $segs] && ![wviewer::browser_devint $token]} {
    set pent {}
    set ptype [wviewer::browser_curtype $token]
    foreach n $browsersigs($token) { lappend pent [wviewer::signal_entry $n $ptype] }
    # ⚠ THE SECOND ARGUMENT IS THE LIVE VALUE, NOT A HARDCODED 1. Hardcoding it
    # would ask about a model the user cannot get to by ticking one box.
    set pent [wviewer::browser_class_filter $pent 1 \
                [wviewer::browser_srccur $token]]
    set prp {}
    if {[info exists browserraw($token)]} { set prp $browserraw($token) }
    set plab [wviewer::browser_root_label $prp]
    set prows {}
    catch {set prows [wviewer::browser_rows_multi \
             [list [list {} {} $pent $plab]] $plab]}
    set pmatched 0
    catch {lassign [wviewer::browser_node_for $prows $segs \
             [wviewer::browser_root_id $prows]] pid pmatched}
    if {$pmatched == [llength $segs]} {
      set bx $f.opt.dev
      if {![catch {winfo exists $bx} bex] && $bex} {
        catch {$bx invoke}
        set rows4 {}
        if {[info exists browserrows($token)]} { set rows4 $browserrows($token) }
        lassign [wviewer::browser_node_for $rows4 $segs \
                   [wviewer::browser_root_id $rows4]] id4 matched4
        set rows $rows4 ; set id $id4 ; set matched $matched4 ; set r12 1
      }
    }
  }
  if {$matched < [llength $segs]} {
    # ⚠ IMPROVE-OR-RESTORE, and it is a MEASURED necessity, not caution.
    # `browser_reload` sets the inventory to whatever `signal_list` answered —
    # and a read that FAILS answers with nothing, so a bare retry can replace a
    # perfectly good tree with an empty one and turn a `partial` into an `err`.
    # Observed on the first cut of this proc. So the reload's result is kept
    # ONLY when it matches MORE of the path than the snapshot did; otherwise
    # both arrays and the widget are put back exactly as they were.
    set keepsigs $browsersigs($token)
    set keeprows $rows
    set keepdbs {}
    if {[info exists browserdbsigs($token)]} { set keepdbs $browserdbsigs($token) }
    # ...and the SELECTION with them: `browser_populate` clears it, so without
    # this an `err` would silently drop the user's selection — the one thing
    # decision 11's "leave the user where they were" forbids on this branch.
    set keepsel {}
    catch {set keepsel [$tv selection]}
    catch {wviewer::browser_refresh $token 1}
    set rows2 {}
    if {[info exists browserrows($token)]} { set rows2 $browserrows($token) }
    lassign [wviewer::browser_node_for $rows2 $segs \
               [wviewer::browser_root_id $rows2]] id2 matched2
    if {$matched2 > $matched} {
      set rows $rows2 ; set id $id2 ; set matched $matched2
    } else {
      set browsersigs($token) $keepsigs
      set browserrows($token) $keeprows
      set browserdbsigs($token) $keepdbs
      catch {wviewer::browser_populate $tv $keeprows}
      catch {$tv selection set $keepsel}
    }
  }
  set asked [join $segs .]
  if {$matched == 0} {
    set m "no signals under '$asked'"
    # the Search and Filter bars can hide a node that IS in the raw, which is
    # otherwise indistinguishable from "the raw has no such node". Naming them
    # is the fix; CLEARING them behind the user's back is not (declared limit).
    if {[wviewer::browser_bars_active $token]} {
      append m " (the Search/Filter bar may be hiding it)"
    }
    return [wviewer::browser_say $token err $m]
  }
  wviewer::browser_reveal $token $id
  set landed [wviewer::browser_id_path $id]
  # R12's LAST SENTENCE — "the box stays ticked" — is expressed by the ABSENCE of
  # any untick here rather than by a line of code. The arm reports what it did and
  # leaves the browser in the scope the user can now see and un-tick themselves.
  if {$r12 && $matched == [llength $segs]} {
    return [wviewer::browser_say $token unhidden $id $landed $asked]
  }
  if {$matched < [llength $segs]} {
    return [wviewer::browser_say $token partial $id $landed $asked]
  }
  return [wviewer::browser_say $token ok $id $landed $asked]
}

# =============================================================================
# §F item F1 — SCOPE THE BROWSER TO A DIGITAL DATABASE
# doc/claude/specs/mixed_signal_signal_browser.md §F (F1), RULINGS 5d/5e/F1c.
#
# THE MIRROR OF browser_show_path, ONE DATABASE OVER. `browser_show_path` walks
# the CURRENT database's design root; a code block's signals are in a VCD that
# is a DIFFERENT registry slot, and the tree already knows how to show it — item
# 14 gives every foreign database its own header and re-keys its rows `d:<idx>|`.
# What was missing is a way to ASK for a node in a named database.
#
# ⚠⚠ IT IS A SECOND PROC, NOT A `db` ARGUMENT ON browser_show_path, AND THAT IS
# A DECISION. browser_show_path carries item 18's device-internals probe, the
# improve-or-restore reload and nine pinned outcome sentences, all of them
# reasoning about the CURRENT database's inventory (`browsersigs`) — a probe
# that means nothing for a foreign slot. Threading a database through it would
# have made every one of those arms conditional, and the analog path is the one
# path in this file that must stay byte-identical.
# =============================================================================

# PURE. 1 when the row model is DB-HEADERED, i.e. the tree is currently showing
# one top-level node per database (item 15's R7 shape).
#
# ⚠ IT IS A READ OF THE TREE, NOT OF THE CHECKBOX, and that is deliberate twice
# over. The scope box has exactly ONE reader in this file, by a rule with a
# check counting its bare name file-wide; and the question here is not "is the
# box ticked" but "are the foreign databases' rows in the model I am about to
# walk" — which is the fact that actually decides whether the walk can succeed.
proc wviewer::browser_rows_headered {rows} {
  foreach r $rows {
    if {[regexp {^d:[0-9]+} [wviewer::dget $r id {}]]} { return 1 }
  }
  return 0
}

# PURE. 1 when row `id` is in the model.
proc wviewer::browser_row_exists {rows id} {
  foreach r $rows { if {[wviewer::dget $r id {}] eq $id} { return 1 } }
  return 0
}

# The `d:<registry idx>` GROUP ID of the database whose file is `path`, plus
# whether it is the CURRENT one: `{<gid> <cur>}`, or `{}` when this viewer holds
# no such database.
#
# Paths are compared NORMALIZED, never as strings: the resolver's answer comes
# out of the run-directory map artifact while the registry's comes from
# `xschem raw info`, and the same file reaches the two through different spellings
# (`~`, a relative rundir, a symlinked scratch directory).
proc wviewer::browser_db_group_id {token path} {
  variable browserdbsigs
  variable browserraw
  variable browsercurdb
  if {$path eq {}} { return {} }
  set want $path
  catch {set want [file normalize $path]}
  set cp {}
  if {[info exists browserraw($token)]} { set cp $browserraw($token) }
  if {$cp ne {}} {
    set n $cp
    catch {set n [file normalize $cp]}
    if {$n eq $want} {
      set gid {}
      if {[info exists browsercurdb($token)]} {
        set gid [wviewer::dget $browsercurdb($token) id {}]
      }
      return [list $gid 1]
    }
  }
  if {[info exists browserdbsigs($token)]} {
    foreach db $browserdbsigs($token) {
      set p [wviewer::dget $db path {}]
      if {$p eq {}} { continue }
      set n $p
      catch {set n [file normalize $p]}
      if {$n eq $want} { return [list [wviewer::dget $db id {}] 0] }
    }
  }
  return {}
}

# PURE. 1 when at least one name of `names` lives UNDER dotted scope `scope`.
#
# ⚠ LITERAL AND CASE-SENSITIVE, the same test RULING 5c makes the resolver use
# and for the same measured reason: `vcd_read.c` stores names verbatim because
# Verilog is case-sensitive, so folding here would answer yes for a scope this
# database does not have. It is the POSITIVE TEST that justifies re-scoping the
# tree on the user's behalf below — R12's rule, one item over.
proc wviewer::browser_names_under {names scope} {
  if {$scope eq {}} { return 0 }
  set pfx "$scope."
  set n [string length $pfx]
  foreach nm $names {
    if {[string range $nm 0 [expr {$n - 1}]] eq $pfx} { return 1 }
  }
  return 0
}

# THE COMMAND. A results-database FILE plus a scope INSIDE it -> the tree
# selection, scrolled into view. Same result vocabulary as browser_show_path
# (`ok` / `partial` / `err`) plus one more, and it NEVER throws — it rides a key
# binding through ase::show_in_browser_for_current.
#
#   {alldbs <id> <landed>}   the same shape as `ok`, reported when the foreign
#                            database's rows had to be brought into the tree
#
# ⚠⚠ THE AUTO-SCOPE IS R12's SHAPE, DELIBERATELY: A POSITIVE TEST, ONE DECISION
# POINT, AND IT SAYS WHAT IT DID. With the scope box off, a VCD's rows are not
# in the tree at all, so the branch would be dead on a default browser — and
# ticking the box because the row is missing would tick it for a genuinely
# absent scope too. The question asked instead is the one that justifies the
# change: does THAT database's own inventory really carry this scope? Only then
# is the box invoked, and the result reports `alldbs` so the user is told why
# their tree just grew.
#
# ⚠ THE BOX IS INVOKED, never written: `invoke` runs the checkbutton's own
# -command, which is the searchbar's fire path, which re-filters and repopulates
# exactly as a click does. Setting the variable would move the tick and leave
# the tree stale.
#
# ⚠ AND THE TICK IS PUT BACK IF IT DID NOT HELP. This is the one place this proc
# deviates from R12, whose ⚠ block rejects a confirm guard — R12 has one thing
# to try and this has two failure modes after the tick (the DB's rows appear but
# the SCOPE's rows are filtered out by a bar). Leaving a box the user did not
# tick, for a gesture that then failed, is a side effect with nothing to show
# for it. The positive test above is still what makes the arm testable: forcing
# the decision to always-yes UNTICKS a ticked box and the walk that followed
# cannot find its rows.
proc wviewer::browser_show_db_scope {token dbpath scope} {
  variable windows
  variable browserrows
  variable browserdbsigs
  if {![dict exists $windows $token]} {
    return [wviewer::browser_say $token err {no waveform viewer window is open}]
  }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f.pw.tvf.tv} e] || !$e} {
    return [wviewer::browser_say $token err {the Signal Browser is not built}]
  }
  set segs [wviewer::hier_split $scope]
  if {![llength $segs]} {
    return [wviewer::browser_say $token err \
      {the digital database was resolved but no scope inside it was}]
  }
  # the foreign inventory is what says which registry slot holds this file, and
  # it exists only after a reload — the sidebar may have been built and never
  # shown, which is exactly the Ctrl-Alt-V-from-cold path.
  if {![info exists browserdbsigs($token)] || ![info exists browserrows($token)]} {
    catch {wviewer::browser_refresh $token 1}
  }
  set rows {}
  if {[info exists browserrows($token)]} { set rows $browserrows($token) }
  set g [wviewer::browser_db_group_id $token $dbpath]
  if {$g eq {}} {
    return [wviewer::browser_say $token err "'[file tail $dbpath]' is not among\
 this viewer's results databases"]
  }
  lassign $g gid cur
  set ticked 0
  if {$cur} {
    set root [wviewer::browser_root_id $rows]
  } else {
    set root "$gid|g:"
    if {![wviewer::browser_row_exists $rows $root]} {
      # ⚠ GUARDED, because this proc rides a key binding and a throw here pops
      # bgerror, which is modal under X. The refresh above may have declined
      # (a sidebar that is built but has never been shown), so the array element
      # is not guaranteed even at this point.
      set dnames {}
      if {[info exists browserdbsigs($token)]} {
        foreach db $browserdbsigs($token) {
          if {[wviewer::dget $db id {}] eq $gid} { set dnames [wviewer::dget $db names {}] }
        }
      }
      if {![wviewer::browser_names_under $dnames $scope]} {
        return [wviewer::browser_say $token err "'[file tail $dbpath]' holds no\
 signal under '$scope'"]
      }
      set bx $f.wvsearch.alldb
      if {[catch {winfo exists $bx} bex] || !$bex} {
        return [wviewer::browser_say $token err "'[file tail $dbpath]' is not\
 shown in the tree and the All-DBs box is not available"]
      }
      catch {$bx invoke}
      set rows {}
      if {[info exists browserrows($token)]} { set rows $browserrows($token) }
      if {![wviewer::browser_row_exists $rows $root]} {
        catch {$bx invoke}
        return [wviewer::browser_say $token err "'[file tail $dbpath]' could not\
 be brought into the Signal Browser tree"]
      }
      set ticked 1
    }
  }
  lassign [wviewer::browser_node_for $rows $segs $root] id matched
  if {$matched == 0} {
    set m "no scope '$scope' in '[file tail $dbpath]'"
    if {[wviewer::browser_bars_active $token]} {
      append m " (the Search/Filter bar may be hiding it)"
    }
    return [wviewer::browser_say $token err $m]
  }
  wviewer::browser_reveal $token $id
  set landed [wviewer::browser_id_path $id]
  if {$matched < [llength $segs]} {
    return [wviewer::browser_say $token partial $id $landed $scope]
  }
  if {$ticked} {
    return [wviewer::browser_say $token alldbs $id $landed $scope]
  }
  return [wviewer::browser_say $token ok $id $landed $scope]
}

# 1 when either searchbar carries a non-empty pattern. Never throws.
proc wviewer::browser_bars_active {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set f [dict get $windows $token top].wvbrowser
  foreach bar {wvsearch wvfilter} {
    set d {}
    catch {set d [wviewer::searchbar_get $f.$bar]}
    if {[llength $d] && [wviewer::dget $d pattern {}] ne {}} { return 1 }
  }
  return 0
}

# THE ONE PLACE the four outcome messages are spelled. PURE: a
# `browser_show_path` RESULT -> the sentence for it, so the sidebar's status
# line, the CIW echo and the ASE-side echo cannot drift apart into three
# slightly different accounts of the same event. BX37 pins the strings verbatim.
# ⚠ TWO-PANE item 11 ADDED FIVE KINDS, and they are HERE rather than inline in
# browser_sea_refresh for exactly the reason the header above gives: spec §7.2's
# three states have three different REMEDIES ("clear the bar", "tick the box",
# "this node genuinely has nothing"), so a user who cannot tell them apart is
# stuck. Three sentences written at their point of use are three sentences that
# drift from the spec one at a time.
#
#   seanone   nothing selected — R4 says unreachable with a design root in the
#             tree; BP43a is the tombstone for the All-DBs case where it is not
#   seaempty  a PURE ANCESTOR. MEASURED: 12 of tb_bandgap's 44 kept nodes and 18
#             of its 128 raw ones have no own-level signals at all. An ANSWER
#   seabars   the Search/Filter bar emptied it (browser_bars_active)
#   seaclass  the CLASS filter emptied it — §7.5's reachable case: a wrapper kept
#             because a descendant carries a real net, whose own level is all
#             device. Distinct from seabars, and distinct from seaempty
#   seacount  the ordinary `<shown> of <own> signals`
#
# ⚠ TWO-PANE ITEM 18 ADDED A TENTH RETURN, `unhidden`, and it belongs HERE for
# the header's own reason rather than beside the code that mints it. R12 ticks
# the device-internals box on the user's behalf, which grows tb_bandgap's tree
# from 45 nodes to 129 — a change the user did not ask for and can see. The one
# thing that makes that legitimate rather than alarming is a sentence saying it
# happened, and a sentence written at its point of use is a sentence that drifts
# from the sidebar's status line, the CIW echo and the ASE echo one at a time.
# Its shape MATCHES `ok`'s — `{unhidden <row id> <landed path>}` — so `[lindex
# $res 2]` means the same thing in both arms.
#
# ⚠ §F ITEM F1 ADDED AN ELEVENTH, `alldbs`, and it is here for the header's
# reason a third time. Scoping the browser to a code block's VCD needs that
# database's rows in the tree, and with the scope box off they are not there;
# the digital walk therefore ticks the box on the user's behalf — the same
# "grew the tree without being asked, so say so" event R12's tenth kind
# reports, one database over instead of one class of node over. Its shape
# matches `ok`'s for the same reason: `[lindex $res 2]` is the landing.
proc wviewer::browser_msg {res} {
  switch -- [lindex $res 0] {
    ok      { return "showing [lindex $res 2]" }
    partial { return "no signals under '[lindex $res 3]' - showing\
                      [lindex $res 2] instead" }
    root    { return {showing the simulation top level} }
    unhidden { return "showing device internals to reach [lindex $res 2]" }
    alldbs  { return "showing every results database to reach [lindex $res 2]" }
    seanone  { return {no node selected} }
    seaempty { return "[lindex $res 1] has no signals of its own" }
    seabars  { return "[lindex $res 1] of [lindex $res 2] signals\
                       (the Search/Filter bar is hiding them)" }
    seaclass { return "[lindex $res 1] of [lindex $res 2] signals\
                       (device internals are hidden)" }
    seacount { return "[lindex $res 1] of [lindex $res 2] signals" }
  }
  return [lindex $res 1]
}

# Build the result, then SAY it on both viewer surfaces. Returns the result list
# `browser_show_path` returns.
#
# `a`/`b`/`c` are positional because their meaning is per-kind:
#   ok/partial/unhidden -> a=<row id>   b=<landed path>  c=<asked path>
#   err                 -> a=<message>
#   root                -> nothing.
#
# ⚠ TWO-PANE ITEM 18's kind rides the SAME switch, which is what makes the R12
# arm a one-line return in browser_show_path instead of a second place that
# knows how to phrase and echo an outcome. `c` is accepted and dropped exactly
# as `ok` drops it — the sentence names the landing, not the asked path.
proc wviewer::browser_say {token kind {a {}} {b {}} {c {}}} {
  switch -- $kind {
    ok      { set r [list ok $a $b] }
    partial { set r [list partial $a $b $c] }
    root    { set r [list root {}] }
    unhidden { set r [list unhidden $a $b] }
    alldbs  { set r [list alldbs $a $b] }
    default { set r [list err $a] }
  }
  set m [wviewer::browser_msg $r]
  catch {wviewer::browser_status $token $m}
  # issue 0315, RULING (1). The status line above is UNCONDITIONAL and the CIW
  # echo below is not: when one gesture drives both this proc and an ASE command
  # that reports the same answer, the log got the same sentence twice — and on a
  # fall-through the viewer's copy was tagged `error` (red) while the ASE copy
  # was a plain result, so a benign navigation left a failure marker in the log.
  # The ruling is that the ASE command owns the CIW account of its own gesture;
  # `ase::show_in_browser_for_current` arms the flag and this consumes it.
  #
  # ⚠ CONDITIONAL, NOT DELETED, AND THAT IS THE OTHER HALF OF THE RULING. A
  # gesture that reaches the browser WITHOUT an ASE command driving it still
  # reports itself here — that arm is the viewer's own contract, and the tests
  # that call `browser_show_path` directly are exactly such a caller. (Measured
  # while ruling: on this tree `src/ase.tcl` is the ONLY product caller of
  # either entry point, so the unarmed arm has no product user today. It is kept
  # because deleting it would silently make the viewer unable to report a
  # navigation it performs, and re-adding it later would re-mint the sentence
  # somewhere else — the one thing BK34's one-formatter oracle exists to stop.)
  #
  # ⚠ AND THE VIEWER-SIDE GESTURES THE ISSUE NAMES DO NOT COME THROUGH HERE AT
  # ALL. The tree's own double-click and `Descend to here` echo their own
  # `signal browser:` lines from their own sites, so this ruling did not quieten
  # them and could not: it moved only what the two path-walking entry points
  # say.
  if {![wviewer::browser_say_quiet_consume $token]} {
    if {[lindex $r 0] eq {err}} {
      catch {wviewer::echo "signal browser: $m" error}
    } else {
      catch {wviewer::echo "signal browser: $m"}
    }
  }
  return $r
}

# issue 0315: ARM the one-shot suppression for the NEXT `browser_say` on $token,
# or clear it. `on` 0 is the disarm `ase.tcl` runs at the tail of its gesture, so
# an armed-but-never-consumed flag cannot silence a later, unrelated say.
#
# ⚠ IT DOES NOT STACK. Two arms with no say between them are one arm — the ASE
# gesture arms before each of its up-to-three viewer calls and each call
# consumes its own, so nesting never arises and a counter would only be a
# second thing to get wrong.
proc wviewer::browser_say_quiet {token {on 1}} {
  variable sayquiet
  if {$on} {
    set sayquiet($token) 1
  } else {
    catch {unset sayquiet($token)}
  }
  return $on
}

# issue 0315: read AND consume. 1 means "this say does not echo to the CIW".
proc wviewer::browser_say_quiet_consume {token} {
  variable sayquiet
  if {![info exists sayquiet($token)]} { return 0 }
  unset sayquiet($token)
  return 1
}

# --- item 9: THE WIDTH RULE ---------------------------------------------------
# MEASURED, and it is a rule rather than a magic number because both halves are
# forced. One searchbar wants 755 px (type 97, pat 204, syntax 87, case 92,
# search 69, err 172, plus padding); with pack propagation ON, a 700 px toplevel
# came back with sidebar width 700 AND canvas width 700 — a BROKEN layout, not a
# narrow one. So propagation goes off and the width is derived:
#
#  * the `err`-label subtraction is what keeps settled decision 5's Search
#    button MAPPED when the cap does not bind (at 583 px it is on-screen; the
#    error label is the one thing allowed to clip, and browser_refresh mirrors
#    its message into the status line so decision 4 survives the clip);
#  * the 45% cap is what stops the sidebar eating the canvas on a small window;
#  * the 240 px floor stops a tiny window collapsing it to nothing.
#
# It runs from browser_show's PACK branch ONLY, never from browser_build: the
# toplevel is mapped there (so `winfo width` is real), and build must stay
# geometry-neutral or item 8's BS21 — "built but not packed, nothing moved" —
# stops meaning anything.
#
# ⚠ ITEM 15 WIDENED IT, IT DID NOT REPLACE IT. `want` {} (every pre-item-15
# caller, and browser_show is still the only one) derives the base width exactly
# as before; a positive integer REPLACES the derived base and then goes through
# THE SAME cap and floor. That shape is forced: a restored width must not be
# able to exceed 45% of a toplevel that is now smaller than the one it was
# measured on, and the clamp may not be factored out into a shared helper
# either — test_wave_sigbrowser.tcl's BT08 greps four literals inside THIS body
# and that file is FROZEN (ruling 30). Consequence, declared in the receipt: the
# dict field round-trips exactly, the PIXELS do not when the window changed size.
proc wviewer::browser_width {token {want {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set f $top.wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return 0 }
  # ⚠ MEASURED, AND THE WHOLE RULE DEPENDS ON IT: a frame's `reqwidth` is
  # computed by the packer on the IDLE queue, so straight after `pack $f` the
  # searchbar still reports 1 and the derivation below collapses to the 240 px
  # floor -- which clips the entry so hard that Tk will not even deliver a
  # synthetic <KeyRelease> to it (the bar's own widgets are unmapped). Idle
  # tasks only; this is a gesture path, never an event pump, so nothing
  # re-enters.
  # ⚠⚠ ISSUE 0312 NARROWED THE FLUSH TO THE DERIVING PATH, AND THAT IS A FIX,
  # NOT A TIDY-UP. The flush exists for ONE reason — to make the `reqwidth` read
  # below real — and an explicit positive `want` discards that derivation three
  # lines later, so on that path it was pure cost. The cost was not small: a
  # grip drag calls this proc per <B1-Motion>, `update idletasks` services the
  # idle queue, and `on_configure`'s whole job is to park a
  # `capture_live_view_state` + `regenerate` on that queue. Flushing from inside
  # the motion handler therefore ran a FULL graph regeneration per pixel of
  # drag. The paragraph above used to end "this is a gesture path, never an
  # event pump, so nothing re-enters" — with a live drag that sentence became
  # false, and this guard is what makes it true again.
  if {![string is integer -strict $want] || $want <= 0} { catch {update idletasks} }
  catch {pack propagate $f 0}
  set w 280
  catch {set w [expr {[winfo reqwidth $f.wvsearch] -
                      [winfo reqwidth $f.wvsearch.err]}]}
  # ⚠⚠ AND THE DERIVATION HAS TO IGNORE THE WRAP, OR IT EATS ITS OWN TAIL.
  # `searchbar_reflow` (issue 0312) lays the bar out on TWO ROWS when it is
  # narrower than it needs, which SHRINKS `reqwidth $f.wvsearch` — the input
  # this rule just read. So a second `browser_show` on a wrapped sidebar derived
  # ~180 and landed on the 240 px floor: the sidebar collapsed because it had
  # once been narrow. `searchbar_need` answers what the bar needs FLAT, in both
  # layouts, so it is the stable input. Guarded and additive: the four literals
  # BT08 greps are untouched above, and a bar that is not wrapped (every
  # pre-0312 state, and the `wvfilter` bar) never enters here.
  catch {
    if {[wviewer::searchbar_wrapped $f.wvsearch]} {
      set w [wviewer::searchbar_need $f.wvsearch]
    }
  }
  # item 15: an explicit want REPLACES the derived base, then takes the same
  # cap/floor below. Non-integer / non-positive is ignored, so `{}` is literally
  # the pre-item-15 path.
  if {[string is integer -strict $want] && $want > 0} { set w $want }
  set cap 0
  catch {set cap [expr {int(0.45 * [winfo width $top])}]}
  if {$cap > 0 && $w > $cap} { set w $cap }
  if {$w < 240} { set w 240 }
  catch {$f configure -width $w}
  return $w
}

# --- issue 0312: THE WIDTH PREFERENCE AND THE GRIP -----------------------------
# THE PERSISTED WIDTH, a SEPARATE proc from `browser_width` for exactly the
# reason `browser_sash_pref` is separate from `browser_sash`: the accessor above
# APPLIES a width and answers the derived/capped pixel count, so reading it as
# "what the user chose" would mean every window that was ever shown has a
# preference. Absence here means "nobody chose one".
#
# ⚠⚠ AND IT IS THE ONE THING STANDING BETWEEN THE WRAP AND A COLLAPSING SIDEBAR.
# `browser_width`'s derived base is `[winfo reqwidth $f.wvsearch]` minus the err
# label, and `searchbar_reflow` (issue 0312's other half) makes that number
# SHRINK when the bar goes to two rows -- a wrapped bar reports ~350 px, so the
# derivation lands under the 240 px floor. `browser_show` therefore SEEDS this
# preference with the first show's derived answer and passes it back on every
# later show, so a Ctrl-B/Ctrl-B round trip on a wrapped bar re-applies 450 px
# instead of re-deriving 240. That seed is also what makes a grip drag survive
# hiding the sidebar.
#
# ⚠ 0 IS "NO PREFERENCE", and it is `browser_width`'s own ignore value: a
# non-integer / non-positive `want` there is documented as literally the
# pre-item-15 path. So `browser_width $token [browser_width_pref $token]` is
# exactly `browser_width $token` on a window nobody has a preference for --
# which is what keeps item 15's shape and BT08/BP07's four literals untouched.
# PURE: no widget, no throw.
proc wviewer::browser_width_pref {token {want {}}} {
  variable browserwidth
  if {[string is integer -strict $want] && $want > 0} {
    set browserwidth($token) $want
  }
  if {![info exists browserwidth($token)]} { return 0 }
  return $browserwidth($token)
}

# The grip's widget path. One place, because five procs name it.
proc wviewer::browser_grip_path {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  return [dict get $windows $token top].wvbgrip
}

# Build (once) and PACK the drag grip: a 6 px full-height bar between the
# sidebar and the canvas. Returns 1 when it is packed, 0 otherwise.
#
# ⚠⚠ WHY THIS IS A GRIP FRAME AND NOT THE `ttk::panedwindow` ISSUE 0312's THIRD
# CANDIDATE ASKED FOR. A horizontal panedwindow has to OWN both panes, so
# `.wvbrowser` and `.drw` would become children of it -- and
# `test_wave_sigbrowser.tcl` is FROZEN by ruling 30 while asserting, on a LIVE
# widget tree, that `.wvbrowser` is a pack slave of the TOPLEVEL packed before
# `.drw` (BS24, BS41, BT21) as well as source-grepping `browser_show`'s pack
# line verbatim (BS01/BS02). Re-parenting reds five checks in a file that may
# not be edited, and invalidates item 0's `xschem reload` waiver, which was
# measured on precisely that packing. A grip packed BETWEEN the two leaves the
# slave ORDER `.wvbrowser` < `.wvbgrip` < `.drw`, which `bs_order` still reads
# as `a-before-b`, and leaves every literal where it was.
#
# ⚠ `-before $top.drw`, same as the sidebar and for the same reason: the canvas
# is packed `-side right -fill both -expand true`, so anything packed AFTER it
# gets nothing.
#
# ⚠ BUILT LAZILY, HERE, NOT IN `browser_build`. That proc must stay
# geometry-neutral (item 8's BS21) and its children set is pinned to exactly
# seven by BT21/BR20; the grip is a child of the TOPLEVEL, created the first
# time the sidebar is actually shown.
proc wviewer::browser_grip_show {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set g $top.wvbgrip
  if {[catch {winfo exists $g} e] || !$e} {
    catch {
      # ⚠⚠ NOT `[ase::theme header]`, AND THE REASON IS ALREADY MEASURED IN THIS
      # FILE. `tabbar_refresh`'s header records header (#e8e8e8) against panel
      # (#f2f2f2) as an eyeball FAILURE -- "TEN levels apart in the ASE locked
      # palette ... on screen all three buttons were indistinguishable" -- and
      # answers it with three simultaneous cues. A 6 px divider has room for
      # one, so that one has to carry: #b8b8b8 is dark enough to read as a
      # deliberate edge against both the panel and the white canvas. It is a
      # LITERAL rather than a palette name because the locked palette has four
      # entries and none of them is a divider tone; adding one would restyle
      # every ASE surface that names it. ⚠ THIS IS A PIXEL AND IT IS OWED AN
      # EYEBALL -- no check can say a divider "looks like a divider".
      frame $g -width 6 -background #b8b8b8 \
        -cursor sb_h_double_arrow -takefocus 0 -relief raised -borderwidth 1
    }
    if {[catch {winfo exists $g} e2] || !$e2} { return 0 }
    bind $g <Button-1>        [list wviewer::browser_grip_press $token %X]
    bind $g <B1-Motion>       [list wviewer::browser_grip_motion $token %X]
    bind $g <ButtonRelease-1> [list wviewer::browser_grip_drop $token]
  }
  if {[catch {pack info $g}]} {
    if {[catch {pack $g -side left -fill y -before $top.drw}]} { return 0 }
  }
  return 1
}

# Unpack the grip. Spelled against `$g`, never `$f`, so `browser_show` still
# carries exactly ONE `pack forget $f` (BS02 counts that literal).
proc wviewer::browser_grip_hide {token} {
  set g [wviewer::browser_grip_path $token]
  if {$g eq {}} { return 0 }
  if {[catch {winfo exists $g} e] || !$e} { return 0 }
  catch {pack forget $g}
  return 1
}

# <Button-1>: capture the anchor pair {root-x, current sidebar width}. Both are
# needed -- tracking the pointer's absolute x alone would jump the divider to
# the pointer on the first motion event, which is what a grab-anywhere-on-a-
# 6px-bar gesture must not do.
proc wviewer::browser_grip_press {token X} {
  variable windows
  variable gripdrag
  if {![dict exists $windows $token]} { return 0 }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return 0 }
  # ⚠⚠ `cget -width`, NOT `winfo width`, AND THE TWO REALLY DO DIVERGE. Every
  # other party to this gesture works in the CONFIGURED width: `browser_width`
  # writes it, `browser_grip_drop` reads it back. `winfo width` is what the
  # packer GRANTED, and after a window shrink that nothing re-clamped (the rule
  # runs from `browser_show`'s pack branch only) the two differ by the shortfall
  # -- so the first motion event would jump the divider by exactly that
  # difference, which is the one thing the two-value anchor exists to prevent.
  # `winfo width` remains the fallback for a frame with no configured width yet.
  set w 0
  catch {set w [$f cget -width]}
  if {![string is integer -strict $w] || $w <= 1} {
    catch {set w [winfo width $f]}
  }
  if {![string is integer -strict $w] || $w <= 1} { return 0 }
  if {![string is integer -strict $X]} { return 0 }
  set gripdrag($token) [list $X $w]
  return 1
}

# <B1-Motion>: apply the new width THROUGH `browser_width`, and that is the
# whole reason this proc is three lines of arithmetic instead of thirty.
#
# ⚠⚠ THE CLAMP IS NOT DUPLICATED HERE, ON PURPOSE. `browser_width`'s 45% cap and
# 240 px floor are inline in that proc because BT08 greps them there and the
# file is FROZEN (ruling 30) -- so a second copy in this proc would be a second
# authority on the same rule, and the two would drift the first time one of them
# was tuned. Item 15 already built the door: a positive integer `want` REPLACES
# the derived base and then takes THE SAME cap and floor. A drag is just a
# `want` that arrives 60 times a second.
#
# ⚠ CONSEQUENCE, DECLARED RATHER THAN HIDDEN: a live drag therefore CANNOT widen
# the sidebar past 45% of the toplevel. On the shipped 1000 px window that is
# 450 px and the search bar needs 583 px, which is why issue 0312 needed BOTH
# halves -- the grip reaches the narrow end (item 5 step 7's ~250 px), the wrap
# is what makes `All DBs` and `Search` reachable at the wide end.
#
# ⚠ `$want < 1` IS FLOORED TO 1 rather than passed through: `browser_width`
# ignores a non-positive `want` and falls back to the DERIVED base, so dragging
# left past the sidebar's own left edge would make it JUMP back to 450 instead
# of stopping at the 240 floor.
proc wviewer::browser_grip_motion {token X} {
  variable gripdrag
  if {![info exists gripdrag($token)]} { return 0 }
  if {![string is integer -strict $X]} { return 0 }
  set a $gripdrag($token)
  set want [expr {[lindex $a 1] + $X - [lindex $a 0]}]
  if {$want < 1} { set want 1 }
  return [wviewer::browser_width $token $want]
}

# <ButtonRelease-1>: store what the drag actually landed on. Reads the LIVE
# frame rather than the arithmetic, so what is remembered is the CLAMPED width
# -- exactly `browser_sash_drop`'s rule one axis over, and the reason the array
# still has one writer (`browser_width_pref`).
proc wviewer::browser_grip_drop {token} {
  variable windows
  variable gripdrag
  catch {unset gripdrag($token)}
  if {![dict exists $windows $token]} { return 0 }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return 0 }
  set w 0
  catch {set w [$f cget -width]}
  if {![string is integer -strict $w] || $w <= 1} { return 0 }
  return [wviewer::browser_width_pref $token $w]
}

# 1 when this window's sidebar is showing. An unknown token, or one whose
# window was never built, reads 0 -- the sidebar does not exist before the
# window does, and "no window" must be an ANSWER, not a throw.
proc wviewer::browser_shown {token} {
  variable browser
  if {$token eq {}} { return 0 }
  if {![info exists browser($token)]} { return 0 }
  return [expr {$browser($token) ? 1 : 0}]
}

# Pack / unpack the sidebar to match the mirror -- `readout_show` (:7080)
# verbatim in shape, turned through 90 degrees.
#
# ⚠ `-before $top.drw` IS MANDATORY AND ITS EXACT SPELLING IS LOAD-BEARING.
# The canvas is packed `-side right -fill both -expand true` (xschem.tcl), so a
# plain `-side left` AFTER it in the packing order gets whatever is left, i.e.
# nothing -- the sidebar collapses, not the canvas. This is also the precise
# line item 0 MEASURED surviving an `xschem reload` on a viewer context
# (doc/claude/signal_browser_batch/receipts/00_precondition.md §3), which is
# what waived the items-8-15 auto-defer. Diverging from it invalidates that
# waiver.
#
# The editor's own toolbar can want the same LEFT slot (`pack $topwin.toolbar
# -side left -fill y -before $topwin.drw`, xschem.tcl) -- `open` already
# `pack forget`s it per window and nothing re-shows it in a viewer, so the two
# left bars cannot stack today.
proc wviewer::browser_show {token} {
  variable windows
  variable browser
  if {![dict exists $windows $token]} { return }
  set top [dict get $windows $token top]
  set f $top.wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return }
  if {[info exists browser($token)] && $browser($token)} {
    if {[catch {pack info $f}]} {
      pack $f -side left -fill y -before $top.drw
      # item 9: sizing belongs HERE, not in browser_build — the toplevel is
      # mapped on this branch, so `winfo width` is a real number.
      #
      # ⚠ WIDENED BY ISSUE 0312, AND ONLY BY AN ARGUMENT. `browser_width_pref`
      # answers 0 — which this rule documents as its own ignore value — for
      # every window nobody has dragged the divider on or restored a width
      # into, so this line is LITERALLY the pre-0312 derived call there.
      #
      # ⚠⚠ IT USED TO ALSO SEED THAT PREFERENCE WITH THE DERIVED ANSWER, AND
      # THAT WAS WRONG TWICE OVER. It made "has a preference" and "has been
      # shown" the same fact — the exact mistake `browser_sash`'s header says
      # the sash default was moved to a local to avoid — and because the seed
      # was the CAPPED answer, a sidebar first shown on a 600 px window stored
      # 270 and then stayed 270 forever, on every later window size, without
      # the user ever touching anything. The seed existed only to defeat the
      # wrap's effect on the derivation; that is now fixed AT the derivation
      # (see `browser_width`), so the seed is gone and absence means what the
      # accessor says it means.
      catch {wviewer::browser_width $token [wviewer::browser_width_pref $token]}
      # issue 0312: the drag grip, packed BETWEEN the sidebar and the canvas.
      # After the width, because it packs `-before $top.drw` and the sidebar
      # must already hold that slot.
      catch {wviewer::browser_grip_show $token}
      # TWO-PANE item 9: the SASH, for the same reason and one step further
      # along. It is a FRACTION of the panedwindow's height, and that height is
      # only real once the pane is MAPPED — on an unmapped one `winfo height`
      # is 1 and `sashpos 0` computes fraction x 0, collapsing the tree pane.
      # `browser_width` has already flushed the idle queue once, but its own
      # `$f configure -width` has not been serviced when it returns, so the
      # queue is flushed again here AND the apply is repeated on the idle queue.
      # Both calls are idempotent and both land before the user can touch the
      # sash, so neither can clobber a drag.
      catch {update idletasks}
      catch {wviewer::browser_sash $token}
      catch {after idle [list wviewer::browser_sash $token]}
    }
    # item 9: SHOW = REPOPULATE. The inventory is a snapshot taken here (see
    # browser_reload), so showing the sidebar is the one moment a raw read is
    # owed. `catch`ed: a refresh that cannot read must not stop the sidebar
    # appearing.
    catch {wviewer::browser_refresh $token 1}
  } else {
    catch {pack forget $f}
    # issue 0312: the grip goes with it. A divider left packed against a hidden
    # sidebar is a 6 px strip the user can still drag, resizing something that
    # is not on screen.
    catch {wviewer::browser_grip_hide $token}
  }
}

# Keep the View-menu checkbutton's variable in step with the authority, so the
# menu is right however the state last changed (key, command, build) --
# sync_grid_mirror's push-don't-poll rule.
proc wviewer::sync_browser_mirror {token} {
  variable browsershow
  set browsershow($token) [wviewer::browser_shown $token]
}

# Toggle (or set) the sidebar. `want` {} = invert, else 0/1. Returns the NEW
# state, or {} plus a CIW error when no viewer resolves or the word is bad.
#
# grid_toggle's contract MINUS the model half, and the subtraction is
# principled: THIS PROC changes widget geometry only -- no rect token, no C
# state, no context switch of its own.
#
# ⚠ NARROWED BY ITEM 9 (ruling 17: never let a claim outrun its coverage).
# Toggling ON now REPOPULATES the tree, and that read DOES take a 0173 context
# loan -- but one level down, inside `wviewer::signal_list`, which owns the
# enter_ctx/leave_ctx bracket. So "no context switch" remains literally true of
# this proc's body (which is all BS08 greps), and is NOT true of the gesture as
# a whole. The loan lives in signal_list; the rest of the paragraph stands. It
# must NOT capture or regenerate either: packing the sidebar resizes the canvas,
# which already goes <Configure> -> wviewer::on_configure -> configure_apply,
# and that path captures and regenerates. A second one here would double-fold
# and double-draw. Kept from grid_toggle: refuse-a-no-op-without-logging, and
# exactly ONE replay line carrying the resolved state and the explicit token.
proc wviewer::browser_toggle {{want {}} {token {}}} {
  variable windows
  variable browser
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: no waveform viewer window to toggle the signal browser in" error
    }
    return {}
  }
  set cur [wviewer::browser_shown $token]
  if {$want eq {}} {
    set new [expr {$cur ? 0 : 1}]
  } elseif {[string is boolean -strict $want]} {
    set new [expr {[string is true -strict $want] ? 1 : 0}]
  } else {
    if {[info exists ::has_x] && [info commands ::ciw_echo] ne {}} {
      ciw_echo "wviewer: bad signal browser state '$want' (expected 0/1 or {})" error
    }
    return {}
  }
  if {$new == $cur} { return $cur }
  set browser($token) $new
  wviewer::sync_browser_mirror $token
  wviewer::browser_show $token
  wviewer::log_action [list wviewer::browser_toggle $new $token]
  return $new
}

# View > Signal Browser checkbutton -command. Tk has ALREADY written the new
# value into the mirror by the time this runs, so it must SET that value -- a
# plain toggle here would invert twice and the menu would appear dead
# (grid_toggle_from_menu's lesson).
proc wviewer::browser_from_menu {token} {
  variable windows
  variable browsershow
  set want [expr {[info exists browsershow($token)] && $browsershow($token) ? 1 : 0}]
  set r [wviewer::browser_toggle $want $token]
  # a refused toggle must not leave the checkbutton lying -- but only re-sync a
  # token that still HAS a window: re-syncing a dead one would CREATE the very
  # stray array entry `forget` exists to prevent. (A deliberate tightening of
  # the grid_toggle_from_menu precedent; a dead token has no menubar anyway,
  # its toplevel died with it.)
  if {$r eq {} && [dict exists $windows $token]} {
    wviewer::sync_browser_mirror $token
  }
  return $r
}

# The Ctrl-B binding body (Ctrl-L until TWO-PANE item 16, R9) -- the
# grid_toggle_at / clear_all_at pattern: resolve
# the window the KEY went to (%W), never the current xschem context. Silent on a
# foreign canvas.
proc wviewer::browser_toggle_at {W} {
  set token [wviewer::token_for_canvas $W]
  if {$token eq {}} { return {} }
  return [wviewer::browser_toggle {} $token]
}

# =============================================================================
# item 15 — THE BROWSER'S SLICE OF snapshot / restore
# doc/claude/signal_browser_batch/PLAN.md item 15, receipts/15_receipt.md.
#
# One sub-dict under the `browser` key of the ASE `viewer` state, so a restored
# session lands where the user left it: sidebar shown/width, BOTH searchbars,
# the plot destination, the tree's expanded set and selection, and the raw-file
# history.
#
# ⚠⚠ IT IS EMITTED ONLY WHEN IT IS NON-DEFAULT, and that gate is load-bearing
# OUTSIDE this file: `test_wave_modes.tcl` MG9 pins `[dict keys $snap]` to
# exactly {open sharedx rawfile graphs mode target}, and
# `ase::ui::viewer_snapshot`'s difference test would mark every session dirty if
# a new key appeared unconditionally (the same argument the TABS keys are gated
# on). `browser_state_is_default` is the gate.
#
# ⚠ EVERYTHING IS READ THROUGH THE OWNING ITEM'S ACCESSOR — `browser_shown`
# (item 8), `searchbar_get` (items 4/9/14), `plot_dest` (item 7, ruling 24),
# `rawhist_get` (item 13). Nothing here touches `sbcase(`, `sbcfg(`, `dest(` or
# the RECT MODEL: settled decision 13 says browser state derives from
# `xschem raw list` / `xschem raw`, never from graph rects (issue 0186 is open).
#
# ⚠ DELIBERATE EXCLUSIONS KEPT (the PLAN's "do not fix that here"): undo/redo
# history, wave highlights (D4, and WH9j greps this file for `wavehl`) and the
# per-tab `view` range cache all stay out.
# =============================================================================

# The canonical no-op value: what a FRESHLY OPENED window's browser really is.
# PURE. Every field is spelled explicitly rather than derived, so a default that
# drifts in the widgets is a FAILING CHECK (BP41 asserts a real fresh window
# equals this) instead of a gate that quietly stops emitting.
#
# `dest append` is spelled out because item 7 has no open-time seed — `plot_dest`
# answers `append` for a token it has never heard of, so that IS the default.
# The search sub-dict carries `alldbs` and the filter sub-dict does NOT: that is
# item 14's conditional-key contract (only a bar built `-alldbs 1` has it), and
# the two shapes must match `searchbar_get`'s output EXACTLY, key order included,
# or the equality test below can never be true.
#
# ⚠⚠ TWO-PANE ITEM 14 APPENDED THREE KEYS, AND `APPEND` IS THE RULE, NOT THE
# HABIT (spec doc/claude/specs/waveform_signal_browser_two_pane.md §9). The
# equality test below is a WHOLE-DICT STRING COMPARE, so this dict's key order
# and `browser_state`'s build order have to agree exactly. Insert a key in the
# middle of one of them and the gate can never close again: every viewer's
# snapshot grows a `browser` key, and test_wave_modes.tcl MG9 -- a file this
# batch does not own -- goes red with a diff that looks like a value bug.
# BP10 asserts the key list for exactly that reason.
#
# ⚠ THE TWO CLASS-BOX DEFAULTS DIFFER (0 and 1). That is R11 -- device internals
# off, source currents on -- not an asymmetry to be tidied. BP62 is the check,
# and BP13's `srccur 0` leg is the one that catches "tidied".
#
# ⚠ `sash 0` IS "NOBODY CHOSE A SPLIT", NOT A POSITION. 0 is outside the open
# interval the accessor accepts, so it can never be a real preference and needs
# no separate present/absent flag; the layout default (0.55) is the accessor's
# business and deliberately does NOT appear here. If this default were the
# layout one, a fresh window would have to report 0.55 to stay "default", the
# accessor would have to be the reader, and the trap in the paragraph above
# would spring on every window ever opened.
proc wviewer::browser_state_default {} {
  return [dict create \
    shown  0 \
    width  0 \
    search [dict create pattern {} syntax shell case 0 type all alldbs 0] \
    filter [dict create pattern {} syntax shell case 0 type all] \
    dest   append \
    open   {} \
    sel    {} \
    hist   {} \
    sash   0 \
    devint 0 \
    srccur 1]
}

# 1 when `d` says nothing a fresh window does not already say. PURE.
#
# ⚠ `hist` IS EXCLUDED ON PURPOSE (declared divergence D-A). The raw history is
# a GLOBAL, DISK-BACKED store that already outlives the session on its own; if
# it counted here, whether a state file grew a `browser` key would depend on the
# developer's home directory, and MG9 would go red on any machine that had ever
# opened a raw. So the history RIDES ALONG when the sub-dict is emitted for some
# other reason, and an all-default browser simply records no history — which
# costs nothing, because `rawhist_load` reads the same store back at startup.
proc wviewer::browser_state_is_default {d} {
  if {$d eq {}} { return 1 }
  if {[catch {dict remove $d hist} a]} { return 0 }
  return [expr {$a eq [dict remove [wviewer::browser_state_default] hist]}]
}

# --- the tree's own two fields ------------------------------------------------
# EVERY row in the tree, depth-first. Tk-only, never throws.
#
# ⚠⚠ THE "HAS CHILDREN" HEURISTIC WAS REMOVED BY TWO-PANE ITEM 10, AND LEAVING
# IT WOULD HAVE BEEN A SILENT BUG. It said "group rows are exactly the rows with
# children", which was true only while LEAF rows were in the tree. Once item 10
# takes them out, a node whose children were all signals — e.g. `g:x1.x2` in a
# design with no deeper instances — has NO children at all, so it would drop out
# of this list: its `-open` state would stop being saved by `browser_tree_state`
# and stop being restored by `browser_tree_apply`, and the user's collapse of
# exactly the leaf-most nodes would be the part that never persisted. Every item
# in the tree IS a node now, so the predicate is gone rather than reworded.
proc wviewer::browser_tree_nodes {tv {id {}}} {
  set out {}
  if {[catch {$tv children $id} kids]} { return {} }
  foreach k $kids {
    lappend out $k
    foreach d [wviewer::browser_tree_nodes $tv $k] { lappend out $d }
  }
  return $out
}

# `{open <group ids currently expanded> sel <the selection>}`, or {} when there
# is no window / no tree. NEVER throws — it is read from `snapshot`, which runs
# on a window that may be halfway through teardown.
#
# ⚠ THE DEFAULT IS ALL-CLOSED-BUT-THE-ROOT, AND A NON-EMPTY SELECTION — BOTH
# SIGNS INVERTED BY TWO-PANE ITEM 10, whose header this paragraph still
# described until item 13 corrected it. `browser_populate` now inserts every row
# `-open 0` and opens exactly one exception, the design root (R1/M11), and it
# never leaves the selection empty (R4). So the genuinely non-default values a
# round-trip fixture has to set are the other way round: an OPEN group and a
# selection that is NOT the root (driver note (d): a default-valued field proves
# nothing). test_wave_sigbrowser_i1315.tcl's BP43 block sets exactly those.
proc wviewer::browser_tree_state {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return {} }
  set sel {}
  catch {set sel [$tv selection]}
  set op {}
  foreach id [wviewer::browser_tree_nodes $tv] {
    set o 0
    if {[catch {$tv item $id -open} o]} { continue }
    if {[string is boolean -strict $o] && [string is true -strict $o]} {
      lappend op $id
    }
  }
  return [dict create open $op sel $sel]
}

# The inverse. Ids that no longer exist are skipped (the raw may have changed
# between snapshot and restore), so a stale state can never throw.
#
# ⚠⚠ THE ORDER IS LOAD-BEARING AND NOT OBVIOUS: SELECTION FIRST, OPEN-SET LAST.
# `$tv see` sets EVERY ANCESTOR's `-open` to true (that is browser_reveal's
# central finding), so applying the collapse first and then revealing the
# selection would silently re-expand exactly the groups the user had collapsed.
# `browser_reveal` is still NOT reused here, but the reason CHANGED with
# two-pane item 13: it no longer force-opens the node it lands on, so what is
# left is simply that a RESTORE must let the persisted open set have the last
# word, and reveal is a user gesture that has no open set to lose to.
#
# ⚠⚠⚠ AND THAT IS WHY THE SELECTION'S ANCESTOR CHAIN IS **NOT** UNIONED INTO
# THE APPLIED OPEN SET. PLAN item 13 asks for exactly that union; it is REFUSED,
# and the refusal is recorded here because the next reader will otherwise "fix"
# it back. Spec §4.2 (doc/claude/specs/waveform_signal_browser_two_pane.md):
#     "the persisted `open` set must beat it — BP54 already pins that a
#      persisted collapse beats `see`'s ancestor-expansion, and that check
#      stays green."
# MEASURED, not argued: with NO `open` key the pass below is skipped entirely
# and `see` has already opened the whole chain, so the union is a no-op exactly
# where it would be harmless; with an `open` key that omits an ancestor the pass
# below closes it, which is the one state the union would flip — a §4.2
# violation exactly where it bites. It would also break round-trip idempotency,
# because the widened set is what the next `browser_state` persists, so a user's
# collapse would dissolve over sessions. Implementing it reds BW76
# (test_wave_sigbrowser_panes.tcl), BP53 and BP54
# (test_wave_sigbrowser_i1315.tcl) — three files, one proc.
#
# ⚠ It must run AFTER `browser_show`, never before: showing the sidebar calls
# `browser_refresh $token 1`, and `browser_populate` deletes every row and
# re-inserts them all (closed, bar the design root, since two-pane item 10).
proc wviewer::browser_tree_apply {token d} {
  variable windows
  variable browserrows
  if {$d eq {}} { return 0 }
  if {![dict exists $windows $token]} { return 0 }
  set tv [dict get $windows $token top].wvbrowser.pw.tvf.tv
  if {[catch {winfo exists $tv} e] || !$e} { return 0 }
  # ⚠⚠ SPEC §7.3: `sel` IS PERSISTED AS A LIST and the shipped version wrote it
  # from an `extended` tree, so a state file in the wild can hold two ids. R4
  # says the tree holds exactly one — and the widget will NOT enforce it for us:
  # `-selectmode` gates only ttk's CLASS BINDINGS, so `$tv selection set {a b}`
  # really does select two (MEASURED, BW26b in test_wave_sigbrowser_panes.tcl).
  # So the restore narrows: THE FIRST id that STILL EXISTS, which is not
  # `lindex 0` — a dead id at the head must not blank the selection (BW73).
  set want [wviewer::dget $d sel {}]
  set keep {}
  foreach id $want {
    if {$id eq {}} { continue }
    if {![catch {$tv exists $id} ex] && $ex} { set keep [list $id] ; break }
  }
  # ...and §7.3's other half: "a list whose ids have all gone falls back to the
  # root". The root comes from the ROW MODEL, never from the widget — the row
  # list is where "there is no design root" is expressible at all (the All-DBs
  # state), and `[lindex [$tv children {}] 0]` would answer a DB header there.
  #
  # ⚠ NON-EMPTY IS PART OF THE CONDITION, and the narrow reading is deliberate:
  # an EMPTY `sel` has no ids that "have gone", `browser_state_apply` passes
  # `sel {}` for every legacy and default state, and R4 is already satisfied by
  # `browser_populate`'s own root selection. Firing here would move the
  # selection on every plain restore. BW74's second leg pins that.
  # ⚠ A row model with NO design root answers `{}`, and that absence is an
  # ANSWER: the fallback is then a NO-OP, never a clear and never a throw.
  if {![llength $keep] && [llength $want]} {
    set rows {}
    if {[info exists browserrows($token)]} { set rows $browserrows($token) }
    set rid [wviewer::browser_root_id $rows]
    if {$rid ne {} && ![catch {$tv exists $rid} rex] && $rex} { set keep [list $rid] }
  }
  if {[llength $keep]} {
    catch {$tv selection set $keep}
    catch {$tv focus [lindex $keep 0]}
    catch {update idletasks}
    catch {$tv see [lindex $keep 0]}
  }
  # ...and only NOW the expanded set, over the top of whatever `see` opened. An
  # absent `open` key (a state written before this item) leaves the tree as
  # `browser_populate` built it.
  if {[dict exists $d open]} {
    set op [dict get $d open]
    foreach id [wviewer::browser_tree_nodes $tv] {
      catch {$tv item $id -open [expr {[lsearch -exact $op $id] >= 0 ? 1 : 0}]}
    }
  }
  return 1
}

# --- the reader and the writer ------------------------------------------------
# THE READER. {} for a token with no window / no sidebar, which
# `browser_state_is_default` reads as "default" so `snapshot` emits nothing.
proc wviewer::browser_state {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return {} }
  set d [wviewer::browser_state_default]
  dict set d shown [wviewer::browser_shown $token]
  set w 0
  catch {set w [$f cget -width]}
  if {![string is integer -strict $w] || $w < 0} { set w 0 }
  dict set d width $w
  set s {}
  catch {set s [wviewer::searchbar_get $f.wvsearch]}
  if {$s ne {}} { dict set d search $s }
  set fl {}
  catch {set fl [wviewer::searchbar_get $f.wvfilter]}
  if {$fl ne {}} { dict set d filter $fl }
  dict set d dest [wviewer::plot_dest $token]
  set t [wviewer::browser_tree_state $token]
  dict set d open [wviewer::dget $t open {}]
  dict set d sel  [wviewer::dget $t sel  {}]
  dict set d hist [wviewer::rawhist_get]
  # TWO-PANE item 14, spec §9. APPENDED, in this order, matching
  # browser_state_default's key order exactly -- the gate is a whole-dict string
  # compare and the two orders are one contract (BP64 pins the order, BP10 the
  # key list).
  #
  # ⚠⚠ THE PREFERENCE READER, NEVER THE SASH ACCESSOR AND NEVER A LIVE
  # `sashpos`/`winfo height`. A live read can never equal a constant default, so
  # the gate below would be permanently false and every viewer's snapshot would
  # grow a `browser` key. That is the item's sabotage S1 and it reds BP63, BP69,
  # BP41, BP42 and MG9 in test_wave_modes.tcl.
  dict set d sash   [wviewer::browser_sash_pref $token]
  dict set d devint [wviewer::browser_devint $token]
  dict set d srccur [wviewer::browser_srccur $token]
  return $d
}

# THE WRITER. `{}` -> 0 immediately, and that is the pre-item-15 back-compat
# arm: a state file with no `browser` key leaves the fresh window exactly as
# `open` built it.
#
# ⚠ STEP ORDER IS FORCED, TWICE OVER:
#   * the width goes AFTER `browser_show`, because the pack branch recomputes it;
#   * the tree state goes AFTER `browser_show` too, because that call repopulates
#     the tree from `xschem raw list` and wipes both fields.
# And both go only when the sidebar restores SHOWN (item 9's D6 — there is no
# populated tree while it is hidden; declared divergence D-D).
#
# ⚠ IT WRITES `dest` AND `browser` DIRECTLY rather than through `set_plot_dest`
# / `browser_toggle`, which BOTH `log_action`. That is `restore`'s own precedent
# for `mode`/`target`: a rebuild must not fill the replay log with lines nobody
# typed. The VALUE still goes through item 7's normaliser, so a garbage `dest`
# in a hand-edited state lands on the harmless policy. Declared as D-F.
proc wviewer::browser_state_apply {token d} {
  variable windows
  variable browser
  variable dest
  if {$d eq {}} { return 0 }
  if {![dict exists $windows $token]} { return 0 }
  set f [dict get $windows $token top].wvbrowser
  if {[catch {winfo exists $f} e] || !$e} { return 0 }
  catch {wviewer::searchbar_set $f.wvsearch [wviewer::dget $d search {}]}
  catch {wviewer::searchbar_set $f.wvfilter [wviewer::dget $d filter {}]}
  catch {set dest($token) [wviewer::dest_norm [wviewer::dget $d dest append]]}
  # TWO-PANE item 14: R11's two class boxes, restored BEFORE `browser_show`.
  # THE ORDER IS FORCED -- they are CLASS FILTERS, and `browser_show` populates
  # the tree and the sea, so restoring them afterwards would build the sidebar
  # once with the wrong signal set and once with the right one, with a visible
  # flash and a `see`/selection pass run against the wrong rows. BP65 pins it.
  #
  # ⚠ THE FALLBACKS ARE 0 AND 1 AND THEY ARE NOT A COPY-PASTE (R11): a state
  # file written before this item has neither key, and the window must land on
  # the shipped defaults, which differ.
  # ⚠⚠ AND THAT IS A LIVE PATH, NOT DEFENSIVE PADDING, WHICH IS WHY IT IS NOW
  # CHECKED FROM BOTH SIDES. `ase_window.tcl`'s Save State / Load State writes
  # the session `viewer` dict -- `browser` sub-dict and all -- to a FILE, so
  # EVERY state file written before this item lands here, and swapping the two
  # constants would restore a legacy session with device internals ON and source
  # currents OFF, inverted from R11 and invisible. The fixup that followed this
  # item's verification added BP75 (the two literals, SOURCE, both arms) and
  # BP76 (a legacy dict with both keys REMOVED, applied to a window that was
  # first driven to the OPPOSITE pair, X arm) -- the swap was fully green across
  # four suites before they existed.
  # ⚠ `catch`ed for the same reason the neighbours are: a hand-edited value that
  # is not boolean must leave the window usable at its build default rather than
  # abort the whole restore.
  catch {wviewer::browser_devint $token [wviewer::dget $d devint 0]}
  catch {wviewer::browser_srccur $token [wviewer::dget $d srccur 1]}
  set shown [wviewer::dget $d shown 0]
  if {![string is boolean -strict $shown]} { set shown 0 }
  set shown [expr {[string is true -strict $shown] ? 1 : 0}]
  set browser($token) $shown
  catch {wviewer::sync_browser_mirror $token}
  catch {wviewer::browser_show $token}
  if {$shown} {
    catch {wviewer::browser_width $token [wviewer::dget $d width 0]}
    # issue 0312: and the same number becomes the window's width PREFERENCE, or
    # the next Ctrl-B/Ctrl-B would re-derive and the restored width would
    # evaporate. `browser_width_pref` ignores 0, so a state file with no `width`
    # key (or the `width 0` a never-shown sidebar writes) leaves the window with
    # NO preference — which is the truthful state, and the derived path then
    # sizes it exactly as `browser_show` just did.
    catch {wviewer::browser_width_pref $token [wviewer::dget $d width 0]}
    set ts [dict create sel [wviewer::dget $d sel {}]]
    if {[dict exists $d open]} { dict set ts open [dict get $d open] }
    catch {wviewer::browser_tree_apply $token $ts}
  }
  # TWO-PANE item 14: the SASH, last, and on purpose OUTSIDE the `$shown` arm.
  #   * LAST, because it can only be applied to a MAPPED panedwindow, and it is
  #     `browser_show`'s pack branch (plus the `after idle` re-apply it queues)
  #     that produces one -- the same reason the width goes after the show.
  #   * UNCONDITIONAL, because a restore of a HIDDEN sidebar must still STORE
  #     the preference. The accessor's own height guard makes the apply a no-op
  #     until the pane is mapped, and the show's idle re-apply then puts it in
  #     place the moment the user opens the sidebar. Dropping the preference
  #     here would mean "snapshot taken with the browser closed" silently
  #     forgets a split the user chose.
  #     ⚠⚠ THAT CHOICE IS NOW A CHECK, NOT JUST A DECLARED LIMIT. It rests on
  #     the accessor STORING `$want` BEFORE its own `$h <= 1` guard; moving the
  #     store after the guard was fully green across three suites until the
  #     fixup added BP77, which restores `sash 0.44` into a NEVER-SHOWN sidebar,
  #     asserts the preference is held anyway, and then opens the sidebar and
  #     watches the split land on 0.44 instead of the 0.55 layout default.
  # ⚠ `sash 0` (spec §9's default, i.e. nobody chose a split) is REFUSED by the
  # accessor's own `$want > 0 && $want < 1` guard, so a default state file
  # leaves the layout default alone rather than collapsing a pane. That is why
  # this line needs no gate of its own.
  catch {wviewer::browser_sash $token [wviewer::dget $d sash 0]}
  catch {wviewer::rawhist_merge [wviewer::dget $d hist {}]}
  return 1
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
  # Signal Browser sidebar on/off (signal-browser PLAN item 8; the chord moved
  # Ctrl-L -> Ctrl-B in TWO-PANE item 16, R9).
  #
  # ⚠⚠ THE Ctrl-B REJECTION RECORDED HERE WAS OVERRIDDEN, NOT FORGOTTEN. Item 8
  # rejected Ctrl-B because 98 IS a `graphkeys` member and membership is
  # unconditional on modifiers, so key_filter forwarded Ctrl-b to C whenever the
  # pointer was over a graph; the csv carried `key,98,ctrl,graph,graph.forward`
  # and one keystroke would have done two things. R9 overrides that on the
  # ruling that Ctrl-B is the chord users expect for a Browser, and PAYS FOR IT
  # in the two places the old objection named:
  #   * key_filter's graphkeys arm gained a MODIFIER CARVE-OUT for 98 beside the
  #     one Ctrl-d already had, so Ctrl-b is no longer forwarded. `graphkeys`
  #     itself is UNCHANGED -- bare `b` still reaches waves_callback and still
  #     toggles cursor B (measured: graph_flags bit 4, and the Tcl mirror with
  #     it). Deleting 98 from the list instead would have taken bare `b` too.
  #   * the C table's `key 98 ctrl graph graph.forward` row was DELETED from
  #     src/callback.c and src/keybindings.csv was REGENERATED from the builtin
  #     table (never hand-edited -- test_bindings_file byte-compares them).
  # The price is declared, not hidden: over a graph EMBEDDED IN A SCHEMATIC,
  # Ctrl+b now falls through to the canvas arm and toggles sym_txt (spec §10
  # limit 9), and a user who sets `graph_use_ctrl_key 1` loses their only
  # cursor-B chord (limit 8). Both are pinned by checks --
  # tests/headless/test_key_graph_context.tcl and test_wave_sigbrowser_keys.tcl.
  #
  # COLLISION CHECK, RE-RUN FOR THE NEW CHORD and clean on all three of the
  # paths a key can reach this window by:
  #   * key_filter now REFUSES to forward 98 under ControlMask (the carve-out
  #     above), so the C dispatcher never sees the chord from this window. The
  #     only 98 row left in src/keybindings.csv is
  #     `key,98,0,graph,graph.forward,1` -- BARE b, which a Ctrl chord does not
  #     match. (callback.c `case 'b'` under ControlMask toggles symbol text on
  #     the canvas; that is behind the same refused forward and unreachable.)
  #   * NO rc binds <Control-Key-b> on .drw -- grepped again for the new chord,
  #     zero hits across every cadence_style_rc and every src *.tcl -- so
  #     clone_canvas_bindings has nothing to copy onto a viewer canvas, and
  #     strip_bindings would sweep it if it ever did.
  #   * the `break` keeps it that way whatever the tags below this one carry.
  #   * Tk maps the virtual event <<PrevChar>> to <Control-Key-b>, which is a
  #     collision class Ctrl-L never had. It does NOT fire here: this binding is
  #     on the WaveViewer bindtag, which lives on the CANVAS, and the sidebar's
  #     search entry carries neither that tag nor a toplevel that has it
  #     (measured -- the insert cursor does not move and the sidebar does not
  #     toggle when the chord is typed into the entry).
  if {[bind WaveViewer <Control-Key-b>] eq {}} {
    bind WaveViewer <Control-Key-b> {wviewer::browser_toggle_at %W; break}
  }
  # `Descend to here` — sync the ASE-L session's DESIGN window to the hierarchy
  # path of the browser row(s) selected here (signal-browser PLAN item 11).
  # Shift-E is the free member of the descend family in this window: bare `e`
  # is Delete Empty Strips and Ctrl-E is Delete All Markers, and `E` matches the
  # schematic's own hierarchy keys.
  # THE WRITTEN THREE-PATH COLLISION CHECK, run and clean on all three of the
  # paths a key can reach this window by:
  #   * keysym 69 is NOT in `graphkeys` {97 98 100 115 109 116 65 66 77}, so
  #     key_filter forwards nothing and the C dispatcher never sees it.
  #     src/keybindings.csv has NO row for 69 at all (the shifted rows it does
  #     carry are 65,66,72,75,76,79,80,84,85,90 — verified). callback.c's
  #     `case 'E'` fires only under EQUAL_MODMASK with Alt (schematic in a new
  #     window); bare Shift-E has no arm there.
  #   * NO rc binds <Key-E> on .drw: a grep for `Key-E>` over src/*.tcl,
  #     src/*.c and src/cadence_style_rc returns exactly ONE hit,
  #     src/cadence_style_rc's `# bind .drw <Control-Shift-Key-E>`, and it is
  #     COMMENTED OUT. So clone_canvas_bindings has nothing to copy onto a
  #     viewer canvas — and strip_bindings sweeps every widget-level sequence
  #     off a viewer canvas anyway.
  #   * the `break` keeps it that way whatever the tags below this one carry.
  # ⚠ THIS TAG CANNOT REACH THE TREE. A treeview's bindtags are {<tv> Treeview
  # <top> all} (measured), so this binding only fires with the CANVAS focused;
  # browser_build carries the tree's own <Key-E> for where the user actually is.
  if {[bind WaveViewer <Key-E>] eq {}} {
    bind WaveViewer <Key-E> {wviewer::browser_descend_at %W; break}
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
  # ---- TABS (doc/claude/specs/waveform_viewer_tabs.md D10) ------------------
  # Five chords, all here rather than in key_filter, because this tag is the
  # only rc-remappable, sweep-proof binding table in the viewer. Each `break`s,
  # which is what guarantees the chord never travels on to the toplevel, the
  # `all` tag or a future canvas binding.
  #
  # COLLISION CHECK, done on all three paths a key can reach this window by,
  # and one of them would be catastrophic:
  #   * Ctrl-N is `file.clear_schematic` in the C binding table
  #     (src/keybindings.csv key,110,ctrl,canvas,...) and
  #     `cadence::new_blank_window` in cadence_style_rc (`bind .drw`). Neither
  #     reaches here: key_filter forwards nothing for keysym 110, and
  #     strip_bindings sweeps the cloned widget-level bind. The Ctrl-E shape.
  #   * ⚠ Ctrl-Q in the C dispatcher is `quit_xschem` -- it QUITS THE
  #     APPLICATION (callback.c case 'q' under ControlMask), and it is live on
  #     a schematic canvas. It cannot reach a viewer (113 is not in `graphkeys`
  #     and has no intercept arm) and the `break` keeps it that way. This is
  #     the one collision in the set that would be catastrophic if the swallow
  #     ever regressed, hence its own test leg.
  #   * Ctrl-C / Ctrl-V: bare `c` is the Cadence copy and bare `v` the vertical
  #     drag constraint; a forward of Ctrl-V would pop readonly_block()'s modal
  #     over the plot, which is the failure the Ctrl-D carve-out in key_filter
  #     was written to prevent. Neither has a canvas row; both are swallowed.
  # None of them is added to `graphkeys` and none gets a key_filter forward arm.
  if {[bind WaveViewer <Control-Key-n>] eq {}} {
    bind WaveViewer <Control-Key-n> {wviewer::new_tab_at %W; break}
  }
  # ⚠ Ctrl-W CHANGED MEANING (D9a, user ruling 2026-08-03): it closes a TAB,
  # and with only one tab it does NOTHING but say so. It never closes a window
  # any more -- that is Ctrl-Q. The hardcoded key_filter arm that used to
  # destroy the window is gone; leaving it would have fired too, because
  # key_filter is on the WIDGET (bindtags index 0) and returns without `break`,
  # so one keystroke would have closed the tab and then killed the window.
  if {[bind WaveViewer <Control-Key-w>] eq {}} {
    bind WaveViewer <Control-Key-w> {wviewer::close_tab_at %W; break}
  }
  if {[bind WaveViewer <Control-Key-q>] eq {}} {
    bind WaveViewer <Control-Key-q> {wviewer::close_window_at %W; break}
  }
  if {[bind WaveViewer <Control-Key-c>] eq {}} {
    bind WaveViewer <Control-Key-c> {wviewer::copy_traces_at %W; break}
  }
  if {[bind WaveViewer <Control-Key-v>] eq {}} {
    bind WaveViewer <Control-Key-v> {wviewer::paste_traces_at %W; break}
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
#
# SPEC D4 (mixed_signal_signal_browser.md, RULING D4-3): the rule differs by
# KIND of database, so this mirror has to differ too or the number the user
# READS disagrees with the one the engine annotated. A `vcd` database is a
# SPARSE EVENT STREAM: the value at x is the one the last event at or before x
# set, held, never interpolated -- interpolating across the one-tick step
# vcd_read() materializes at a change yields 0.5, which is the VCD encoding of X
# (spec C3), i.e. the readout would say "unknown" about a known signal.
# The two BOUNDARY arms below (pos < 0, pos >= n - 1) were already RULING D4-4's
# "hold, never extrapolate" and are unchanged.
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
  set st {}
  catch {set st [xschem raw sim_type]}
  if {$st eq {vcd}} { return $ya }   ;# HOLD (D4-3)
  if {$xb == $xa} { return $ya }
  return [expr {$ya + ($yb - $ya) * ($x - $xa) / ($xb - $xa)}]
}

# SPEC D4: read a trace's value at cursor position `x` IN THE TRACE'S OWN
# DATABASE. `tr` is a trace dict; its `rawfile`/`sim_type` are the same pair
# db_suffix() puts after the `%` in the emitted `node=` token, so the readout
# and the renderer agree about which database a trace comes from by
# construction.
#
# Without this the readout bar was CURRENT-DATABASE-ONLY: `interp_value` asks
# `xschem raw list` / `raw value`, so a VCD trace beside an analog one simply
# vanished from the cursor line -- the strip drew it, the legend named it, and
# the readout had nothing to say about it. That is the same shape as defect 2 of
# the D1 review round (the browser plotting the wrong database) one layer up.
#
# The switch is bracketed and restored by ABSOLUTE INDEX, including on a throw:
# a swap cannot unwind and this runs on every cursor motion. Returns {} when the
# database cannot be reached or the value cannot be read.
#
# AND IT RESTORES BOTH HALVES OF THE REGISTRY CURSOR (fix round). `extra_idx` is
# the current database; `extra_prev_idx` is where `xschem raw switch_back` GOES,
# and EVERY `xschem raw switch` overwrites it. Putting back only the first half
# is exactly the half-restore batch F item 2 removed from find_closest_wave() --
# and this proc runs once per trace per cursor motion, so a mixed strip under a
# dragged cursor rewrote the session's switch_back destination continuously.
# Measured before the fix: park the registry at current=0/prev=2, call this once,
# and `switch_back` landed on the BORROWED database instead of slot 2.
#
# There is no verb that writes extra_prev_idx directly, but `switch_back` is its
# own inverse, so the pair can be READ without moving anything (two switch_backs
# leave both halves as found) and PUT BACK with two switches: `switch $prev`
# makes prev current, then `switch $cur` makes cur current and leaves prev
# behind it. wviewer::raw_prev_idx is the read half.
proc wviewer::raw_prev_idx {} {
  set p -1
  if {[catch {xschem raw switch_back}]} { return -1 }
  catch {set p [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]}
  catch {xschem raw switch_back}
  return $p
}

# put back the pair (cur, prev) after a borrow. Order matters: prev first.
proc wviewer::raw_cursor_restore {cur prev} {
  if {$cur < 0} { return }
  if {$prev >= 0} { catch {xschem raw switch $prev} }
  catch {xschem raw switch $cur}
}

proc wviewer::trace_cursor_value {tr x} {
  set vec [wviewer::dget $tr vec {}]
  if {$vec eq {}} { return {} }
  set rf [wviewer::dget $tr rawfile {}]
  set st [wviewer::dget $tr sim_type {}]
  if {[wviewer::db_suffix $tr] eq {}} {           ;# no per-trace database
    set y {}
    catch {set y [wviewer::interp_value $vec $x]}
    return $y
  }
  set cur -1
  catch {set cur [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]}
  set prev [wviewer::raw_prev_idx]
  set sw 0
  catch {set sw [xschem raw switch $rf $st]}
  if {$sw != 1} { wviewer::raw_cursor_restore $cur $prev ; return {} }
  set y {}
  catch {set y [wviewer::interp_value $vec $x]}
  wviewer::raw_cursor_restore $cur $prev
  return $y
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

# The readout bar's entry list for a layout's `graphs`: one `{trace display}`
# pair per distinct trace, in layout order.
#
# SPEC D4: the dedupe key is the (vec, DATABASE) TRIPLE, not the bare name. Two
# databases may hold the same signal name -- exactly what spec E produces when
# two d_cosim blocks instantiate one Verilog module -- and deduping on the name
# alone drops one of them from the cursor line and shows the other one's number
# under both legends. Same lesson as defect 2 of the D1 review round
# (browser_leaf_specs, which used to throw the row's `d:N|` away), one layer up.
proc wviewer::readout_entries {graphs} {
  set keys {}
  set out {}
  foreach G $graphs {
    foreach tr [wviewer::dget $G traces {}] {
      set vec [wviewer::dget $tr vec {}]
      if {$vec eq {}} { continue }
      set key [list $vec [wviewer::dget $tr rawfile {}] [wviewer::dget $tr sim_type {}]]
      if {[lsearch -exact $keys $key] >= 0} { continue }
      lappend keys $key
      set nm [wviewer::dget $tr name {}]
      if {$nm eq {}} { set nm $vec }
      lappend out [list $tr $nm]
    }
  }
  return $out
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
    set trs {}
    set disps {}
    foreach e [wviewer::readout_entries [dict get [wviewer::layout_for $token] graphs]] {
      lappend trs   [lindex $e 0]
      lappend disps [lindex $e 1]
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
          foreach tr $trs disp $disps {
            set y [wviewer::trace_cursor_value $tr $x]
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

# --- SIGNAL SEARCH BAR: the ViVA Search toolbar as a megawidget (item 4) -----
# doc/claude/signal_browser_batch/PLAN.md item 4;
# references/viva_cadence_waveform_viewer.md §3.2 (the widget order) and §3.3
# (whole-name wildcards). Settled decisions 3, 4, 5, 6, 7 — and decision 2 in
# full: this is a NEW search surface, so the match subject is the FULL raw name
# (`v(out)`), NOT the stripped form. DRIVER RULING 16's stripped-subject
# carve-out is for the LEGACY `.graphdialog` compat surface ONLY and does not
# reach here; that is exactly why the type dropdown below can exist, since it
# reads the `v(`/`i(` prefix that stripping would destroy.
#
# WHY THIS LIVES HERE AND NOT IN THE `:1447` SIGNAL SEARCH SECTION: that
# section's header promises "PURE: no Tk", and this half is all Tk. The two
# label->code mappers are here rather than there for the same reason in reverse
# — they are the WIDGET's private vocabulary (the on-screen English), and
# `sig_match` must never see a label.
#
# CONSUMERS. This section shipped with ZERO of them (item 4, on purpose, exactly
# as items 1 and 2 did). Item 5 added the FIRST: `wviewer::add_trace_dialog`
# builds a bar with `-command wviewer::add_trace_filter`. Item 8 will add the
# browser sidebar. `grep -n searchbar_build src/wave_viewer.tcl` finds every
# call site — deliberately a grep and not a line number, because line numbers in
# this file have already rotted twice.
#
# ⚠ SO THIS IS NO LONGER BLAST-RADIUS-FREE. A change to the -command contract,
# to the widget paths, or to the four callback arguments now reaches shipping UI
# (the Graph > Add Trace… dialog) and is pinned by the AT group in
# tests/headless/test_wave_sigsearch.tcl.
#
# ⚠ DECLARED DIVERGENCE FROM ViVA §3.2, not a silent omission: ViVA's toolbar
# has SIX controls and this one has five. The dropped one is the fifth, the
# `All DBs` checkbox. An xschem viewer window has exactly ONE raw loaded, so the
# box would have nothing to widen the search to. If a multi-raw viewer ever
# lands it re-enters HERE, as widget six, immediately before `Search`.
#
# WHAT OWNS THE ERROR MESSAGE. Settled decision 4 says an invalid regexp is an
# ERROR, never a silent match-all, and that items 3 and 4 surface it. Item 3
# surfaces it as an EMPTY listbox only (its D4 — `.graphdialog` has no error
# widget). **`$w.err` here is the real error label**, and it is the only place
# in the batch that shows `sig_match`'s message text to a user.

# `All`/`Voltage`/`Current`/`Other` -> sig_match's `-type` codes. PURE.
# Anything unrecognised falls back to `all`, which is the safe direction for a
# filter: a widened list is visible, a silently emptied one looks like "no such
# signal".
proc wviewer::sb_type_code {label} {
  switch -exact -- $label {
    Voltage { return v }
    Current { return i }
    Other   { return other }
  }
  return all
}

# `Shell`/`RegExp` -> sig_match's `-syntax` codes. PURE. Unrecognised -> shell,
# settled decision 7's default, and again the safe direction: a shell pattern
# cannot raise a compile error, so a fallback can never turn into a stuck error
# label.
proc wviewer::sb_syntax_code {label} {
  if {$label eq {RegExp}} { return regexp }
  return shell
}

# --- item 15: the two INVERSES ------------------------------------------------
# code -> the combobox LABEL, so `searchbar_set` can write back exactly what
# `searchbar_get` read. PURE, and both fall back to the DEFAULT label rather
# than throwing: a hand-edited state file carrying `syntax posix` must restore a
# usable bar, and settled decisions 6/7 name Shell/All as the defaults. The pair
# is deliberately total (every input maps), which is what makes
# `sb_*_label [sb_*_code $x]` an identity on every LABEL the comboboxes offer —
# and those are the only values the widgets can hold (`-state readonly`).
proc wviewer::sb_syntax_label {code} {
  if {[string tolower [string trim $code]] eq {regexp}} { return RegExp }
  return Shell
}

# `v`/`i`/`other` -> `Voltage`/`Current`/`Other`; anything else -> `All`.
proc wviewer::sb_type_label {code} {
  switch -exact -- [string tolower [string trim $code]] {
    v     { return Voltage }
    i     { return Current }
    other { return Other }
  }
  return All
}

# --- item 7: the plot-destination codes ---------------------------------------
# `Append` `Replace` `New Strip` `New Tab` <-> append replace newstrip newtab.
#
# dest_norm accepts BOTH spellings ON PURPOSE and case-insensitively: the
# combobox hands it the LABEL (`New Strip`), while a CIW line, a replayed action
# log or item 9's toolbar hands it the CODE (`newstrip`). The space forms
# (`new strip`, `new tab`) are accepted too, since that is what a human types.
#
# ⚠ ViVA's OWN NAMES ARE DELIBERATELY NOT ALIASES. `NewSubWin`/`NewWin` are not
# accepted, because the mapping is not a rename: ViVA's `NewWin` means a WINDOW
# and ours means a TAB. Accepting the ViVA spelling would promise a fidelity
# this does not have.
#
# UNRECOGNISED -> `append`, the same argument sb_type_code's `all` fallback
# makes: Append is the ONLY policy that destroys nothing, so a value we cannot
# parse must land there. A fallback to `replace` or `newstrip` would turn a typo
# into data loss or into a strip nobody asked for. PURE.
proc wviewer::dest_norm {v} {
  switch -exact -- [string tolower [string trim $v]] {
    replace           { return replace }
    newstrip -
    {new strip}       { return newstrip }
    newtab -
    {new tab}         { return newtab }
  }
  return append
}

# code -> the combobox LABEL. Unrecognised -> `Append`, same argument. PURE.
proc wviewer::dest_label {code} {
  switch -exact -- [string tolower [string trim $code]] {
    replace  { return Replace }
    newstrip { return {New Strip} }
    newtab   { return {New Tab} }
  }
  return Append
}

# The four labels, in ViVA's order — the combobox's `-values` and the Options
# cascade's entries read from HERE, so the two can never drift apart.
proc wviewer::dest_labels {} {
  return [list Append Replace {New Strip} {New Tab}]
}

# item 10: the label a MENU shows for `code` on THIS window — dest_label plus
# the one thing a combobox does not have room to say.
#
# ⚠ THE DECLARED LIMIT, SURFACED RATHER THAN PRETENDED AWAY (ruling 24, item 9's
# D2): under MULTI-plot `replace` clears nothing, because plan_plot emits no
# clear key there — so an entry reading `Replace` really means Append. The
# browser menu OFFERS the entry anyway (removing it would make the cascade
# disagree with the Add Trace dialog's dropdown, which offers all four), and
# says so in the label instead.
#
# ONE PLACE, used by BOTH the top `Plot (...)` entry and the cascade's Replace
# entry, so those two can never drift apart. PURE apart from the mode read.
proc wviewer::dest_menu_label {token code} {
  set code [wviewer::dest_norm $code]
  set lab [wviewer::dest_label $code]
  if {$code eq {replace} && [wviewer::plot_mode $token] eq {multi}} {
    append lab { -> appends}
  }
  return $lab
}

# wviewer::searchbar_build parent ?-command cb? ?-showbutton 0|1? ?-name child?
#                                 ?-alldbs 0|1?
#   -> the megawidget's frame path (default `$parent.wvsearch`).
#
# `-command` is called as `<cb> <pattern> <syntax> <case> <type>` — the last
# three already mapped to sig_match's codes — on every live keystroke in the
# entry, on either dropdown's selection, on the Match-case toggle, and on the
# Search button. Settled decision 5 ships BOTH the live filter and the button.
# `-showbutton 0` omits the button entirely (the Filter-bar variant of item 8);
# it is not merely unpacked, so `winfo exists $w.search` is a truthful test of
# the variant. `-name` lets two bars share one parent.
#
# Widget order is ViVA §3.2's, left to right:
#   [type ▾] [pattern________] [syntax ▾] [x] Match case [x] All DBs [Search] <error>
# Defaults: type `All`, syntax `Shell` (decision 7), case OFF (decision 6).
# `-alldbs 1` adds the All-DBs scope box between Match case and Search (item 14,
# ViVA §3.2); without it the widget does not exist and `searchbar_get` does not
# emit the key. The bar itself does nothing with the value — scoping a search
# across results databases is the CONSUMER's business (browser_refresh's).
#
# `$w.err` carries a FIXED `-width 24` and no `-expand`, so its requested width
# is the same whether the message is empty or 200 characters. That is the
# mechanism behind "the error label does not resize the bar" — a long message
# CLIPS at ~24 characters rather than pushing `Search` off the end. The clip
# budget is deliberate; if a consumer needs the full text, the right answer is a
# tooltip, not an elastic label.
proc wviewer::searchbar_build {parent args} {
  variable sbcfg
  variable sbcase
  variable sballdb
  set cb {}
  set showbutton 1
  set alldbs 0
  set child wvsearch
  if {[llength $args] % 2} {
    return -code error "wviewer::searchbar_build: options must come in -opt value pairs"
  }
  foreach {o v} $args {
    switch -exact -- $o {
      -command { set cb $v }
      -showbutton {
        if {![string is boolean -strict $v]} {
          return -code error \
            "wviewer::searchbar_build: -showbutton wants a boolean, got \"$v\""
        }
        set showbutton [expr {[string is true -strict $v] ? 1 : 0}]
      }
      -alldbs {
        if {![string is boolean -strict $v]} {
          return -code error \
            "wviewer::searchbar_build: -alldbs wants a boolean, got \"$v\""
        }
        set alldbs [expr {[string is true -strict $v] ? 1 : 0}]
      }
      -name    { set child $v }
      default  { return -code error "wviewer::searchbar_build: unknown option $o" }
    }
  }
  set w [expr {$parent eq {.} ? ".$child" : "$parent.$child"}]
  destroy $w
  # `ase::theme` FIRST, for its side effect: it lazily creates AseLabelFont /
  # AseEntryFont. The widgets below name those fonts at CREATION time (not only
  # via apply_theme at the end), so they must already exist.
  ase::theme
  frame $w
  ttk::combobox $w.type -state readonly -width 8 \
    -values {All Voltage Current Other}
  $w.type set All
  entry $w.pat -width 20 -font AseEntryFont
  ttk::combobox $w.syntax -state readonly -width 7 -values {Shell RegExp}
  $w.syntax set Shell
  # set the var BEFORE the checkbutton exists, so the widget adopts decision 6's
  # OFF rather than defining the element itself
  set sbcase($w) 0
  checkbutton $w.case -text {Match case} -variable ::wviewer::sbcase($w)
  # item 14 (ViVA §3.2): the All-DBs scope box, on the bars that asked for it.
  # Same "set the var BEFORE the widget" rule as Match case, and same OFF
  # default — searching every open results database is opt-in.
  if {$alldbs} {
    set sballdb($w) 0
    checkbutton $w.alldb -text {All DBs} -variable ::wviewer::sballdb($w)
  }
  if {$showbutton} { button $w.search -text Search }
  label $w.err -text {} -font AseLabelFont -anchor w -width 24
  # issue 0312: the flat one-row layout is now a PROC, because the two-row
  # layout has to be able to put it back byte-for-byte. `searchbar_build` still
  # leaves the bar flat, which is what BAR03 and BAR10 read.
  wviewer::searchbar_pack_flat $w
  set sbcfg($w) [dict create command $cb showbutton $showbutton alldbs $alldbs]
  # EVERY route converges on the one handler, so there is exactly one place a
  # consumer's callback can be invoked from and exactly one place the error
  # label is written.
  bind $w.pat    <KeyRelease>         [list wviewer::searchbar_fire $w]
  bind $w.type   <<ComboboxSelected>> [list wviewer::searchbar_fire $w]
  bind $w.syntax <<ComboboxSelected>> [list wviewer::searchbar_fire $w]
  $w.case configure -command [list wviewer::searchbar_fire $w]
  if {$alldbs} { $w.alldb configure -command [list wviewer::searchbar_fire $w] }
  if {$showbutton} {
    $w.search configure -command [list wviewer::searchbar_fire $w]
  }
  # The `%W` guard is belt-and-braces: a frame path is NOT in its children's
  # bindtags (a child's tags are {child Class Toplevel all}), so today only the
  # frame's own <Destroy> can reach this. It costs nothing and it is the one
  # thing standing between a consumer that adds `$w` to a child's bindtags and a
  # bar that de-registers itself the first time its entry is destroyed.
  bind $w <Destroy> [list wviewer::searchbar_destroyed $w %W]
  ase::ui::apply_theme $w
  # issue 0312: THE ONLY TRIGGER for the two-row layout. A bar narrower than its
  # own controls used to lose them off the right-hand edge silently -- no
  # ellipsis, no chevron, nothing on screen to say a control had been dropped.
  bind $w <Configure> [list wviewer::searchbar_reflow $w]
  $w.err configure -foreground [ase::theme accent]
  return $w
}

# --- issue 0312: THE TWO-ROW LAYOUT -------------------------------------------
# The bar's children in ViVA §3.2 order, skipping the two that only exist on
# some variants. ONE list, so the flat layout, the wrapped layout and the width
# measurement can never disagree about who is in the bar.
proc wviewer::searchbar_kids {w} {
  set out {}
  foreach c {type pat syntax case alldb search err} {
    if {[winfo exists $w.$c]} { lappend out $c }
  }
  return $out
}

# THE FLAT LAYOUT — ViVA §3.2's single row, and the shape `searchbar_build`
# always leaves behind.
#
# ⚠⚠ THE `grid forget` SWEEP FIRST IS MANDATORY, NOT DEFENSIVE. A widget managed
# by `grid` cannot be handed to `pack` -- Tk throws
# "cannot use geometry manager pack inside ... which already has slaves managed
# by grid" -- so unwrapping without releasing the grid leaves the bar with NO
# managed children at all, i.e. an empty strip. That is strictly worse than the
# clipping this whole change exists to remove.
#
# ⚠ THE OPTIONS ARE VERBATIM WHAT `searchbar_build` USED TO PACK, INCLUDING THE
# ASYMMETRIC PADS (`{6 4}` on the leading widget, `{0 6}` on Search and the
# error label). BAR03 asserts `pack slaves $w` and BAR10 the -showbutton 0
# variant's; both read a LIVE bar, so a drifted option here surfaces as a
# spacing change nobody asked for rather than as a red check.
proc wviewer::searchbar_pack_flat {w} {
  variable sbwrap
  # ⚠ THE FOUR MANDATORY CHILDREN ARE GUARDED TOO, and not out of symmetry: this
  # proc runs from a <Configure> BINDING, and a throw out of a binding reaches
  # bgerror, which is modal under X and hangs a headless run (`searchbar_fire`,
  # `browser_refresh` and `add_trace_filter` each state the same rule). Any
  # state where a child is gone while `$w` is alive and still configuring --
  # teardown, a consumer that destroyed one by hand -- must degrade to a
  # half-laid-out bar, never to a hang.
  foreach c [wviewer::searchbar_kids $w] { catch {grid forget $w.$c} }
  catch {pack $w.type   -side left -padx {6 4} -pady 3}
  catch {pack $w.pat    -side left -padx {0 4} -pady 3 -fill x -expand 1}
  catch {pack $w.syntax -side left -padx {0 4} -pady 3}
  catch {pack $w.case   -side left -padx {0 4} -pady 3}
  if {[winfo exists $w.alldb]}  { catch {pack $w.alldb  -side left -padx {0 4} -pady 3} }
  if {[winfo exists $w.search]} { catch {pack $w.search -side left -padx {0 6} -pady 3} }
  catch {pack $w.err    -side left -padx {0 6} -pady 3}
  set sbwrap($w) 0
  return 0
}

# THE TWO-ROW LAYOUT — the QUERY on top (what to look for), the MODIFIERS below
# (how to look, and where). Four grid columns; only column 1 carries a weight,
# so it is the one the entry grows into and the one grid takes space FROM when
# the bar is narrower than the row needs.
#
# ⚠ THE ERROR LABEL IS `grid remove`d, NOT PLACED ON A THIRD ROW. `$w.err` is
# `-width 24` (~172 px), which is half the wrapped bar's whole budget, and it is
# already THE designated clippable: `browser_width`'s rule subtracts exactly its
# reqwidth, and `browser_refresh` mirrors its message into the sidebar's status
# line so settled decision 4 survives the clip (see the width rule's header).
# Giving it a row of its own would cost a third row of sidebar height to display
# a duplicate of what `.ph` is already showing.
#
# ⚠ DECLARED LIMIT. Row 0 alone wants type (~97) + pat (~204) + syntax (~87)
# plus pads, i.e. about 400 px, and row 1's three fixed controls about 260. So
# below roughly 400 px even two rows clip: the entry shrinks first (it is the
# weighted column) and then row 0's tail starts to go. The 240 px floor is
# inside that band. The remedy there is the grip -- widen the sidebar, or the
# window. (An earlier draft of this paragraph said ~350 by adding up the four
# FIXED controls and forgetting that the entry shares row 0.)
proc wviewer::searchbar_pack_wrapped {w} {
  variable sbwrap
  foreach c [wviewer::searchbar_kids $w] { catch {pack forget $w.$c} }
  # guarded for the same reason searchbar_pack_flat's are: this runs from a
  # <Configure> binding and a throw there hangs a headless run.
  catch {grid $w.type   -row 0 -column 0 -sticky w  -padx {6 4} -pady {3 0}}
  catch {grid $w.pat    -row 0 -column 1 -columnspan 2 -sticky ew -padx {0 4} -pady {3 0}}
  catch {grid $w.syntax -row 0 -column 3 -sticky ew -padx {0 6} -pady {3 0}}
  catch {grid $w.case   -row 1 -column 0 -sticky w  -padx {6 4} -pady {0 3}}
  if {[winfo exists $w.alldb]}  { grid $w.alldb  -row 1 -column 1 -sticky w -padx {0 4} -pady {0 3} }
  if {[winfo exists $w.search]} { grid $w.search -row 1 -column 2 -sticky w -padx {0 4} -pady {0 3} }
  catch {grid $w.err -row 1 -column 3 -sticky ew -padx {0 6} -pady {0 3}}
  catch {grid remove $w.err}
  catch {grid columnconfigure $w 0 -weight 0}
  catch {grid columnconfigure $w 1 -weight 1}
  catch {grid columnconfigure $w 2 -weight 0}
  catch {grid columnconfigure $w 3 -weight 0}
  set sbwrap($w) 1
  return 1
}

# 1 while the bar is on two rows. Absence reads 0 — a bar that was never
# reflowed is flat, which is exactly what `searchbar_build` leaves.
proc wviewer::searchbar_wrapped {w} {
  variable sbwrap
  if {![info exists sbwrap($w)]} { return 0 }
  return [expr {$sbwrap($w) ? 1 : 0}]
}

# What the FLAT row needs, in pixels: every child's requested width plus its
# pads, MINUS the error label's.
#
# ⚠⚠ MINUS THE ERROR LABEL, AND THAT SUBTRACTION IS `browser_width`'s, COPIED
# DELIBERATELY. The width rule ships a sidebar sized to hold the bar WITHOUT the
# err label (settled decision 5: Search stays mapped, err is allowed to clip),
# so a threshold that included err would fire at the shipped default width and
# wrap a bar that is not actually losing a control. The two numbers have to be
# the same number or the layout fights the width rule.
#
# ⚠ REQUESTED width, never `winfo width`: this must answer the same thing in
# both layouts, and an actual width is whatever the parent last imposed.
proc wviewer::searchbar_need {w} {
  set need 0
  foreach c [wviewer::searchbar_kids $w] {
    if {$c eq {err}} { continue }
    set rw 0
    catch {set rw [winfo reqwidth $w.$c]}
    if {![string is integer -strict $rw]} { set rw 0 }
    incr need $rw
    # the pads, per widget, as searchbar_pack_flat really spells them: {6 4} on
    # the leading `type`, {0 6} on `search`, {0 4} on the rest.
    incr need [expr {$c eq {type} ? 10 : ($c eq {search} ? 6 : 4)}]
  }
  return $need
}

# <Configure>: pick the layout the current width can actually hold. Returns the
# layout in force (0 flat / 1 wrapped), or -1 when it declined to decide.
#
# ⚠⚠ THE HYSTERESIS BAND IS WHAT STOPS THIS OSCILLATING, and the oscillation is
# real rather than theoretical on the STANDALONE bar (item 5's dialog, and every
# BAR-band test toplevel): there the bar is packed `-fill x` into a toplevel
# that sizes itself to the bar's REQUESTED width, so wrapping shrinks the
# request, which shrinks the toplevel, which re-fires <Configure>. Switching
# only outside a 24 px band, and never re-applying a layout already in force,
# closes both halves of that loop.
#
# ⚠ `winfo width` <= 1 IS "NOT MAPPED YET", not zero width -- the same guard
# `browser_sash` takes on an unmapped panedwindow. Deciding a layout from it
# would wrap every bar at build time, before the packer has run once.
proc wviewer::searchbar_reflow {w} {
  variable sbcfg
  if {![info exists sbcfg($w)]} { return -1 }
  if {[catch {winfo exists $w} e] || !$e} { return -1 }
  # ⚠⚠ THE LAYOUT IS ONLY DECIDABLE WHEN SOMEBODY ELSE OWNS OUR WIDTH, AND
  # WITHOUT THIS GUARD THE HYSTERESIS BAND BECOMES A ONE-WAY LATCH. In a
  # container that sizes itself to its children -- the Add Trace dialog's bar,
  # and every bar a test packs straight into a bare toplevel -- `winfo width $w`
  # IS the bar's own request. Wrapping shrinks that request to about the width
  # of row 0, so the unwrap test (`aw >= need + 24`) can never be true again:
  # unwrapping is the only thing that would make the bar wide enough to unwrap.
  # It would also mean a BAR-band test toplevel could wrap on its first
  # <Configure> and turn `pack slaves $w` into `{}` under BAR03.
  #
  # A container with propagation OFF is exactly the sidebar's situation
  # (`browser_width` does `pack propagate $f 0` and then fixes the width), and
  # it is the ONLY situation where "the bar is narrower than it needs" is a fact
  # about the container rather than about the bar. Anywhere else, a bar that
  # does not fit simply asks for more room and gets it -- there is nothing to
  # solve and nothing that can clip.
  set fixed 0
  set par {}
  catch {set par [winfo parent $w]}
  if {$par ne {}} {
    catch { if {![pack propagate $par]} { set fixed 1 } }
    catch { if {![grid propagate $par]} { set fixed 1 } }
  }
  if {!$fixed} { return -1 }
  set aw 0
  catch {set aw [winfo width $w]}
  if {![string is integer -strict $aw] || $aw <= 1} { return -1 }
  set need [wviewer::searchbar_need $w]
  set cur [wviewer::searchbar_wrapped $w]
  if {!$cur && $aw < $need} { return [wviewer::searchbar_pack_wrapped $w] }
  if {$cur && $aw >= $need + 24} { return [wviewer::searchbar_pack_flat $w] }
  return $cur
}

# The bar's four values as a dict {pattern .. syntax .. case .. type ..}, with
# syntax/case/type already in sig_match's codes so a consumer can splat them
# straight into `sig_match`. `{}` for a widget that is not a live searchbar —
# consumers poll this from `after` handlers and snapshot code, where a hard
# error on a torn-down widget would be the wrong answer.
proc wviewer::searchbar_get {w} {
  variable sbcfg
  variable sbcase
  variable sballdb
  if {![info exists sbcfg($w)]} { return {} }
  if {![winfo exists $w]} { return {} }
  set d [dict create \
    pattern [$w.pat get] \
    syntax  [wviewer::sb_syntax_code [$w.syntax get]] \
    case    [expr {[info exists sbcase($w)] && $sbcase($w) ? 1 : 0}] \
    type    [wviewer::sb_type_code [$w.type get]]]
  # item 14: `alldbs` is CONDITIONAL — present only on a bar built with
  # `-alldbs 1`. An unconditional fifth key would break the shipped contract
  # that this dict has exactly these four (test_wave_sigsearch.tcl BAR11), so
  # every consumer reads it with `dget ... alldbs 0`.
  if {[wviewer::dget $sbcfg($w) alldbs 0]} {
    dict set d alldbs \
      [expr {[info exists sballdb($w)] && $sballdb($w) ? 1 : 0}]
  }
  return $d
}

# --- item 15: THE MISSING TWIN ------------------------------------------------
# `searchbar_get`'s inverse: put a bar back into a state that reader described.
# `d` is searchbar_get's OWN dict shape, so get/set compose to an identity and
# there is no second spelling of the bar's state anywhere.
#
# ⚠ IT WRITES THROUGH THE WIDGETS, and the two `set`s below are NOT a reach-in:
# `sbcase($w)` and `sballdb($w)` ARE the checkbuttons' `-variable`, i.e. the
# widgets' own storage, so writing them is exactly what a click does. Everything
# else goes through the entry and the two comboboxes.
#
# ⚠ IT MUST NOT THROW, for `searchbar_get`'s reason turned around: its callers
# are restore paths that run after a DESTROY, where a half-built or torn-down
# bar is a legal input and a hard error would abort the whole rebuild. 1 when
# the bar was written, 0 when there is no live bar to write.
#
# ⚠ MISSING KEYS FALL BACK TO THE DEFAULTS, not to "leave it alone": restoring a
# dict that predates a field must leave the bar in the state a FRESH bar is in,
# or a restore would inherit whatever the previous session left in the widget.
# `alldbs` is the ONE exception and it is item 14's conditional-key contract: it
# is written only when the caller's dict HAS it AND this bar was built
# `-alldbs 1`, so restoring a Filter-bar dict onto the Filter bar cannot invent
# a scope box, and restoring an old four-key dict onto the Search bar leaves the
# box where the fresh window put it (off).
#
# It ends on ONE `searchbar_fire`, deliberately: the consumer callback then runs
# exactly once for the whole restored state (never once per field), and decision
# 4's error label ends up describing the pattern that is actually in the bar.
proc wviewer::searchbar_set {w d} {
  variable sbcfg
  variable sbcase
  variable sballdb
  if {![info exists sbcfg($w)]} { return 0 }
  if {[catch {winfo exists $w} e] || !$e} { return 0 }
  catch {$w.pat delete 0 end}
  catch {$w.pat insert 0 [wviewer::dget $d pattern {}]}
  catch {$w.syntax set [wviewer::sb_syntax_label [wviewer::dget $d syntax shell]]}
  catch {$w.type   set [wviewer::sb_type_label   [wviewer::dget $d type   all]]}
  set c [wviewer::dget $d case 0]
  if {![string is boolean -strict $c]} { set c 0 }
  set sbcase($w) [expr {[string is true -strict $c] ? 1 : 0}]
  if {[wviewer::dget $sbcfg($w) alldbs 0] && [dict exists $d alldbs]} {
    set a [dict get $d alldbs]
    if {![string is boolean -strict $a]} { set a 0 }
    set sballdb($w) [expr {[string is true -strict $a] ? 1 : 0}]
  }
  catch {wviewer::searchbar_fire $w}
  return 1
}

# THE handler. Body order is load-bearing:
#   1. read the four values (searchbar_get, the one reader);
#   2. VALIDATE through THE ONE matcher — `sig_match` on an EMPTY signal list,
#      so the match loop never runs and only the `^(?:$pat)$` compile at
#      `:1573-1574` happens. Nothing here re-implements matching; that is the
#      `:1465` rule and it is why an error message shown to a user is always
#      byte-identical to the one the consumer's own sig_match call will produce;
#   3. write the error label — the message on `{err ...}`, EMPTY otherwise,
#      which is decision 4's "clears on the next valid keystroke" clause;
#   4. invoke the consumer callback ALWAYS, invalid pattern included. The
#      consumer calls sig_match itself and gets the same `{err ...}`; deciding
#      whether to blank a list or hold the last good one is item 5's and item
#      8's call, not this widget's.
#
# ⚠ THIS PROC MUST NOT THROW. It rides a <KeyRelease> pump, and a Tcl error
# there pops bgerror, which is modal under X and HANGS a headless run. Both the
# validation and the user callback are catch-wrapped; a throwing consumer
# callback puts its own message in `$w.err`, so it is visible and never silent.
# Same discipline as `readout_refresh`, for the same reason.
proc wviewer::searchbar_fire {w} {
  variable sbcfg
  if {![info exists sbcfg($w)]} { return }
  set d [wviewer::searchbar_get $w]
  if {$d eq {}} { return }
  set pat  [dict get $d pattern]
  set syn  [dict get $d syntax]
  set case [dict get $d case]
  set type [dict get $d type]
  set msg {}
  if {![catch {wviewer::sig_match {} $pat -syntax $syn -case $case} r]} {
    if {[lindex $r 0] eq {err}} { set msg [lindex $r 1] }
  } else {
    set msg $r
  }
  wviewer::searchbar_error $w $msg
  set cb [dict get $sbcfg($w) command]
  if {$cb ne {}} {
    if {[catch {uplevel #0 [linsert $cb end $pat $syn $case $type]} e]} {
      wviewer::searchbar_error $w $e
    }
  }
  return
}

# Set (or, with an empty `msg`, clear) the bar's error label.
proc wviewer::searchbar_error {w msg} {
  if {![winfo exists $w.err]} { return }
  $w.err configure -text $msg
}

# <Destroy> trampoline: act only on the BAR's own destruction, never a child's.
proc wviewer::searchbar_destroyed {w W} {
  if {$W ne $w} { return }
  wviewer::searchbar_forget $w
}

# Drop every trace of the bar from the namespace. What the `-variable {}` first
# actually buys, MEASURED on Tk 8.6.14 rather than assumed (an earlier version of
# this comment overstated it in both directions):
#   * on the <Destroy> route it is a NO-OP. Tk destroys a frame's children
#     BEFORE the frame's own <Destroy> fires, so `$w.case` is already gone by the
#     time the trampoline gets here and the configure errors into its own catch.
#     It is NOT what makes the destroy path leak-free — the two `unset`s are;
#   * unsetting the element while the widget is live does NOT re-create it on the
#     spot (Tk's var trace only re-establishes itself on TCL_TRACE_UNSETS). The
#     NEXT toggle does: `invoke` writes on/offvalue back into the name.
# So this line is load-bearing on exactly ONE path — a consumer calling
# `searchbar_forget` by hand on a still-live bar (which is why this is a separate
# proc from the trampoline). Detached, a later toggle has nowhere to write and
# the forget stays final. That path is pinned by BAR29 in
# tests/headless/test_wave_sigsearch.tcl.
proc wviewer::searchbar_forget {w} {
  variable sbcfg
  variable sbcase
  variable sballdb
  variable sbwrap
  catch {$w.case configure -variable {}}
  # item 14: exact parity with Match case — the All-DBs element must not outlive
  # the bar either, or a per-window array grows one entry per closed viewer.
  catch {$w.alldb configure -variable {}}
  catch {unset sbcfg($w)}
  catch {unset sbcase($w)}
  catch {unset sballdb($w)}
  # issue 0312: the layout flag is per-bar state keyed by the same path, so it
  # dies with the bar for the same reason the other three do.
  catch {unset sbwrap($w)}
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
  variable atdsigs
  if {![dict exists $windows $token]} { return {} }
  # ⚠ §F item F6: A FRESH DIALOG IS NEVER BORN ARMED, AND NOTHING HERE HAS TO
  # SAY SO. `ase::ui::dialog_frame` opens with an unconditional
  # `catch {destroy $w}` (src/ase_window.tcl:1286), which fires this dialog's own
  # <Destroy> and therefore `add_trace_forget` — the SINGLE owner of dropping
  # `atddb`. An explicit clear here would be a second owner that no sabotage
  # could reach (MEASURED: deleting it reds nothing), so it is deliberately not
  # written. Only the browser's lower pane arms a database, and it arms AFTER
  # this returns, so the Graph menu and the TREE's `Send to Add Trace…` both
  # start from the name-only rule they have always used. `FD68`.
  set top [dict get $windows $token top]
  set w [ase::ui::dialog_frame $top.wvadd {Add Trace}]
  set gcount [llength [dict get [wviewer::layout_for $token] graphs]]
  # item 7's PIXEL deliverable: the plot-DESTINATION dropdown, at row 0, ABOVE
  # `Graph:` — every existing row shifted by +1.
  # WHY A ROW AND NOT A COLUMN: the form's measured grid is 3 columns wide and
  # column 2 holds ONLY the listbox scrollbar, so a `Destination:` label parked
  # there would detach the scrollbar from the listbox by the label's width.
  # Every free cell in this form is in column >= 2; a new row is the only clean
  # cell there is.
  # It shows the PERSISTED per-window choice, so reopening the dialog shows what
  # was chosen last (wviewer::plot_dest, which defaults to Append).
  label $w.ldest -text Destination: -font AseLabelFont -anchor w
  ttk::combobox $w.dest -state readonly -width 10 -values [wviewer::dest_labels]
  $w.dest set [wviewer::dest_label [wviewer::plot_dest $token]]
  grid $w.ldest -row 0 -column 0 -sticky w -padx {8 6} -pady 2
  grid $w.dest  -row 0 -column 1 -sticky w -padx {0 8} -pady 2
  label $w.lgraph -text Graph: -font AseLabelFont -anchor w
  ttk::combobox $w.graph -state readonly -width 6
  if {$gcount > 1} {
    set vals {}
    for {set i 0} {$i < $gcount} {incr i} { lappend vals $i }
    $w.graph configure -values $vals
    $w.graph set [expr {$gcount - 1}]
    grid $w.lgraph -row 1 -column 0 -sticky w -padx {8 6} -pady 2
    grid $w.graph  -row 1 -column 1 -sticky w -padx {0 8} -pady 2
  } else {
    $w.graph configure -values 0
    $w.graph set [expr {$gcount > 0 ? $gcount - 1 : 0}]
  }
  set ee [ase::ui::dialog_row $w 2 Expression: expr]
  set ne [ase::ui::dialog_row $w 3 {Name (optional):} name]
  label $w.lvars -text {Raw variables (double-click to use):} \
    -font AseLabelFont -anchor w
  listbox $w.vars -height 8 -font AseEntryFont -exportselection 0 \
    -background [ase::theme table] -yscrollcommand [list $w.vsb set]
  scrollbar $w.vsb -command [list $w.vars yview]
  grid $w.lvars -row 4 -column 0 -columnspan 2 -sticky w -padx 8 -pady {6 0}
  grid $w.vars  -row 6 -column 0 -columnspan 2 -sticky nsew -padx {8 0}
  grid $w.vsb   -row 6 -column 2 -sticky ns -padx {0 8}
  grid rowconfigure $w 6 -weight 1
  label $w.err -text {} -font AseLabelFont -anchor w
  grid $w.err -row 7 -column 0 -columnspan 3 -sticky we -padx 8
  # `extended` so several traces can be added from one pick (PLAN items 5+6).
  # add_trace_ok now adds ONE TRACE PER SELECTED ROW, in listbox order (item 6).
  $w.vars configure -selectmode extended
  # INVENTORY FIRST, and through wviewer::signal_list — THE accessor (settled
  # decisions 2 and 13). It is also the issue-0173 loan bracket, which the bare
  # `new_schematic switch $wp` this replaces was NOT: that switch never switched
  # back, leaving the viewer's wm title clobbered. Declared as D1.
  set atdsigs($token) {}
  foreach e [wviewer::signal_list $token] {
    lappend atdsigs($token) [dict get $e name]
  }
  set rawnote {}
  if {![llength $atdsigs($token)]} {
    set rawnote {no raw data loaded - variable list unavailable}
  }
  set sb [wviewer::searchbar_build $w -command [list wviewer::add_trace_filter $token]]
  grid $sb -row 5 -column 0 -columnspan 3 -sticky we -padx 8 -pady {4 2}
  # The OPEN population goes through the SAME route the live filter uses, reading
  # the bar's REAL defaults — so the opening list can never drift from decisions
  # 6/7 the way a separate `foreach ... insert` would.
  wviewer::searchbar_fire $sb
  # ⚠ THE `%W` GUARD IS MANDATORY HERE, unlike the searchbar's. `$w` is a
  # TOPLEVEL, and a toplevel IS in its children's bindtags — MEASURED on Tk
  # 8.6.14: `bindtags .p1.kid` = {.p1.kid Label .p1 all}, so destroying ANY
  # child of this dialog fires this binding with %W set to that child. Item 4's
  # note that its own guard is dead code is about a plain FRAME and does NOT
  # transfer. Pinned by AT20.
  bind $w <Destroy> [list wviewer::add_trace_forget $token %W $w]
  bind $w.vars <Double-Button-1> [list wviewer::add_trace_pick $token]
  ase::ui::dialog_buttons $w 8 [list wviewer::add_trace_ok $token] \
    [list destroy $w]
  bind $ee <Return> [list wviewer::add_trace_ok $token]
  bind $ne <Return> [list wviewer::add_trace_ok $token]
  ase::ui::apply_theme $w
  $w.err configure -foreground [ase::theme accent]
  if {$rawnote ne {}} { $w.err configure -text $rawnote }
  focus $ee
  return $w
}

# The Add Trace dialog's searchbar consumer (item 5). Repopulate the raw-vars
# listbox with the subset of the snapshotted inventory that matches the bar.
#
# ⚠ MUST NOT THROW. It is invoked from wviewer::searchbar_fire, which rides the
# entry's <KeyRelease> pump; a Tcl error there pops bgerror, which is modal under
# X and HANGS a headless run. Every exit below is a guard, never an error.
#
# The match subject is the FULL raw name (settled decision 2) — `atdsigs` holds
# what signal_list's `name` field gave, never the sig_bare-stripped form, because
# the type dropdown derives from the `v(`/`i(` prefix.
proc wviewer::add_trace_filter {token pat syn case type} {
  variable windows
  variable atdsigs
  if {![dict exists $windows $token]} { return }
  if {![info exists atdsigs($token)]} { return }
  set w [dict get $windows $token top].wvadd
  if {![winfo exists $w.vars]} { return }
  # Snapshot the selection BY NAME: the repopulate below invalidates indices,
  # so a user's picks would silently move to different rows (or vanish) if this
  # were kept as integers.
  set keep {}
  foreach i [$w.vars curselection] { lappend keep [$w.vars get $i] }
  set r [wviewer::sig_match $atdsigs($token) $pat \
           -syntax $syn -case $case -type $type]
  # Settled decision 4: an invalid pattern is an ERROR, and the BAR has already
  # written it to its own error label. HOLD the last good list rather than
  # blanking it — item 4's contract comment explicitly delegates this choice to
  # here. (The legacy .graphdialog blanks; ruling 16 makes that surface the
  # exception.) Declared as D3.
  if {[lindex $r 0] ne {ok}} { return }
  $w.vars delete 0 end
  set i 0
  foreach n [lindex $r 1] {
    $w.vars insert end $n
    if {[lsearch -exact $keep $n] >= 0} { $w.vars selection set $i }
    incr i
  }
  return
}

# Drop the dialog's inventory snapshot when the dialog itself goes away.
# See the ⚠ at the `bind $w <Destroy>` site: the `%W ne $w` guard is REQUIRED,
# because a toplevel is in its own children's bindtags and every child destroy
# would otherwise evaporate the cache while the dialog is still up.
proc wviewer::add_trace_forget {token W w} {
  variable atdsigs
  # §F item F6: the lower pane's one-shot database goes with the dialog it was
  # armed for — a dialog that was closed unanswered must not hand its database
  # to the NEXT one, which is plot_dbs_take's discipline in this dialog's terms.
  variable atddb
  if {$W ne $w} { return }
  catch {unset atdsigs($token)}
  catch {unset atddb($token)}
  return
}

# --- §F item F6: the lower pane's `Send to Add Trace…` carries its database ---
#
# `plot_dbs_arm`/`plot_dbs_take` in miniature, for the OTHER route out of the
# pane's context menu. See `atddb`'s declaration for why the arm carries the NAME
# as well as the index, and `browser_sea_send_to_add_trace` for what arms it.
proc wviewer::atd_db_arm {token name db} {
  variable atddb
  if {$db eq {}} { catch {unset atddb($token)} ; return {} }
  set atddb($token) [list $name $db]
  return {}
}
# CONSUMES, exactly as plot_dbs_take does: an arm that survived its own OK would
# retarget whatever the user typed next.
proc wviewer::atd_db_take {token} {
  variable atddb
  if {![info exists atddb($token)]} { return {} }
  set v $atddb($token)
  unset atddb($token)
  return $v
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

# Add Trace > OK. A typed Expression WINS and adds exactly ONE trace (the RPN
# path is untouched, so `xschem raw add` stays single-shot). With the Expression
# empty, the listbox selection drives the add: ONE TRACE PER SELECTED ROW, in
# LISTBOX order (PLAN item 6).
#
# item 7 gave this proc a DESTINATION and, with it, a mandatory ORDER:
#   read the dialog -> refuse -> prepare the window -> plan -> create -> clear
#   -> add -> report
# Each step of that order is load-bearing and the reasons are inline below.
#
# ⚠ UNDER `append` THE RESULT IS BYTE-IDENTICAL TO WHAT IT WAS: plan_plot's
# single arm with a valid target returns `new 0`, no `clear` key, and every
# target equal to `$gi` — so the add loop below runs exactly the adds the old
# straight-line code ran, in the same order, with the same messages. That is
# why MS00-MS18 and test_wave_viewer's G11/G12/G12b are this rewrite's real
# regression oracle, not the new DS checks.
proc wviewer::add_trace_ok {token} {
  variable windows
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvadd
  if {![winfo exists $w]} { return }
  set gi   [$w.graph get]
  set rpn  [string trim [$w.expr get]]
  set name [string trim [$w.name get]]
  # §F item F6: THE LOWER PANE'S ONE-SHOT DATABASE, TAKEN FIRST THING and read
  # exactly like plot_signals reads its own arm — before any early return, so a
  # refused OK cannot leave it to retarget the next gesture.
  lassign [wviewer::atd_db_take $token] atd_nm atd_db
  # The dropdown IS the setting: choosing it in the dialog and pressing OK
  # persists it for the window (item 7's "persisted per window").
  set dest [wviewer::dest_norm [$w.dest get]]
  wviewer::set_plot_dest $dest $token
  # SNAPSHOT THE PICKS NOW, BY NAME. Two independent reasons, both measured:
  # item 5's AT14 (a repopulate invalidates listbox indices, names survive it)
  # and item 7's New Tab (dest_prepare DESTROYS this dialog — after that point
  # `$w.vars` does not exist at all).
  set names {}
  if {$rpn eq {}} {
    foreach i [$w.vars curselection] { lappend names [$w.vars get $i] }
  }
  # THE REFUSAL RUNS BEFORE dest_prepare, and it must: a refused OK may not
  # leave a stray new tab (or a fresh empty strip) behind. Refusing after the
  # preparation would make "one Name cannot cover N traces" a destructive
  # gesture.
  if {[llength $names] > 1 && $name ne {}} {
    wviewer::atok_report $w \
      "one Name cannot cover [llength $names] traces - clear the Name field, or select a single row"
    return
  }
  # ⚠ AFTER THIS LINE `$w` MAY BE GONE (New Tab destroys the dialog — MEASURED).
  # Every widget read above is done; every message below goes through
  # atok_report, which survives a vanished dialog.
  if {![wviewer::dest_prepare $token $dest]} {
    wviewer::atok_report $w "cannot open a new tab for this plot"
    return
  }
  # RE-READ the strip list: a New Tab replaced the whole layout.
  set gs [dict get [wviewer::layout_for $token] graphs]
  if {$rpn eq {}} {
    # Nothing typed and nothing picked: hand the EMPTY rpn to add_trace so its
    # own "empty expression - type one or pick a raw variable" stays the single
    # owner of that string. Duplicating it here would be a second place to keep
    # in sync.
    if {![llength $names]} { set names [list {}] }
  } else {
    # A typed expression wins and is exactly ONE trace (item 6's MS08/MS09).
    # The destination governs BOTH paths — it is about WHERE, not about WHICH.
    set names [list $rpn]
  }
  set n [llength $names]
  # The dialog is a SINGLE-plot gesture whatever the window's plot mode says
  # (it names one Graph), so plan_plot is asked in `single` — the destination is
  # the only thing that moves the landing.
  #
  # ⚠ The 6th argument is the EMPTY-strip list and it is NOT {} any more. It
  # cannot change where this gesture lands (the single arm consults it only when
  # the stack is empty, where it is empty too, and `auto` stays -1 on purpose:
  # the dialog NAMES its graph, so it may name the auto strip), but it is what
  # lets plan_replace_clear tell "Replace onto a strip holding traces" from
  # "Replace onto a strip that is already empty" — without it, Replace onto an
  # empty target made a no-op clear_graph_traces call (a wavehl remap, a marker
  # sweep and a redraw for nothing). DS04c pins the pure half; DS23b is THE
  # oracle for this line and nothing else is (it records the clear calls the OK
  # actually made), so do not delete it thinking counts cover it — they cannot:
  # clearing an empty strip changes no count.
  set plan [wviewer::plan_plot single [llength $gs] $gi $n \
                               -1 [wviewer::empty_graph_indices $gs -1] $dest]
  set nnew [dict get $plan new]
  if {$nnew > 0} {
    set fresh {}
    for {set k 0} {$k < $nnew} {incr k} { lappend fresh [wviewer::empty_graph] }
    # the single arm always appends at the BOTTOM — that is the index its
    # targets name (plan_plot's newstrip comment)
    wviewer::set_graphs $token [concat $gs $fresh]
  }
  # CLEAR AFTER creation, BEFORE the adds. Only `replace` ever emits the key,
  # and it never names a strip this plan just made.
  foreach ci [wviewer::dget $plan clear {}] {
    wviewer::clear_graph_traces $token $ci
  }
  set added 0
  foreach nm $names ti [dict get $plan targets] {
    # ⚠⚠ §F item F6: the armed database applies to the ARMED NAME AND NOTHING
    # ELSE. `add_trace`'s 6th argument overrides the name search entirely, which
    # is right for a pointer the user made by clicking a row under a specific
    # database's header and wrong for anything they typed over it — so the text
    # must still be byte-for-byte what the pane prefilled. `{}` is every other
    # path through this dialog, and `add_trace` then behaves exactly as it always
    # did (decision 4: the current DB wins, then the first other DB that has it).
    set tdb {}
    if {$atd_db ne {} && $nm eq $atd_nm} { set tdb $atd_db }
    set err [wviewer::add_trace $token $ti $nm $name {} $tdb]
    if {$err ne {}} {
      # DELIBERATE NON-ROLLBACK (PLAN item 6 + driver note (f); settled decision
      # 11's rollback rule governs the hierarchy-sync items, not this one). The
      # traces already added STAY, so the message must say HOW MANY, or the user
      # cannot tell what state the graph is in. The suffix appears only when
      # there really was a batch — a single pick keeps add_trace's message
      # byte-for-byte as it has always been.
      # ⚠ item 7 EXTENDS the non-rollback: under Replace the target has ALREADY
      # been emptied by the time an add fails, so a failed Replace can leave the
      # strip with FEWER traces than it started with. Declared, not fixed —
      # rolling back here would need a snapshot/restore this policy does not
      # have (DS29 pins the behaviour so it cannot change silently).
      if {$n > 1} { append err " (added $added of $n, stopped at '$nm')" }
      wviewer::atok_report $w $err
      return
    }
    incr added
  }
  # `catch` so a destination that already took the dialog down (New Tab) does
  # not throw here — and an EXPLICIT empty return, because `catch`'s own 0 would
  # otherwise become this proc's result and break every caller that asserts a
  # successful OK returns nothing.
  catch {destroy $w}
  return {}
}

# Show an Add Trace error. THE dialog may be GONE — New Tab's dest_prepare
# destroys it (tab_drop_transients), MEASURED — so "the label I want to write to
# has vanished" must be an ASSERTABLE VALUE, never an exception: a bare
# `$w.err configure` there would throw out of add_trace_ok, up through whatever
# called it, and (in a test) into the outer catch, silently skipping the rest of
# the file while the failure count still looked plausible.
#
# The fallback is wviewer::echo, the CIW+logfile seam the tab commands already
# use. That makes New Tab's error reporting ASYMMETRIC with the other three
# destinations (CIW, not the dialog's red label) — a declared consequence of the
# dialog being destroyed, not an oversight.
proc wviewer::atok_report {w msg} {
  if {[winfo exists $w.err]} {
    $w.err configure -text $msg
    return dialog
  }
  wviewer::echo "wviewer: $msg" error
  return echo
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
  # ⚠ THE Ctrl-W / Ctrl-Shift-W ARM THAT LIVED HERE IS GONE
  # (doc/claude/specs/waveform_viewer_tabs.md D11, 2026-08-03). It called
  # `wviewer::close`, i.e. destroyed the WINDOW. Ctrl-W now closes a TAB and is
  # a spoken no-op when there is only one, and it lives on the `WaveViewer`
  # BINDTAG with the other four tab chords -- which is also what makes it
  # rc-remappable, as a hardcoded arm here never was. It could not stay in both
  # places: this proc is bound on the WIDGET (bindtags index 0) and returns
  # WITHOUT `break`, so the tag binding fires too and one keystroke would have
  # closed the tab and then killed the window.
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
    # right for a/s (Ctrl+a, Ctrl+s are real ctx=graph rows in keybindings.csv).
    # TWO of the members now have a live Ctrl collision, and BOTH are handled
    # here as MODIFIER CARVE-OUTS — `graphkeys` keeps every keysym it had, so
    # the BARE key of each pair still forwards exactly as before:
    #   * `d` (100): Ctrl-D is the viewer's Clear All on the WaveViewer bindtag,
    #     and there is NO ctx=graph row for Ctrl+d — so a forward falls through
    #     to the schematic `case 'd'`, whose ControlMask branch is
    #     delete_files(), a MODAL FILE DIALOG over a readonly viewer.
    #   * `b` (98): TWO-PANE item 16 (R9) moved the Signal Browser to Ctrl-B on
    #     the same bindtag, and DELETED the C table's
    #     `key 98 ctrl graph graph.forward` row with it — so a forward would now
    #     fall through to the schematic `case 'b'`, whose ControlMask branch
    #     toggles xctx->sym_txt. One keystroke would open the browser AND flip
    #     symbol text behind it. Refusing the forward leaves the tag binding to
    #     toggle, and BARE `b` still reaches waves_callback for cursor B.
    # Refusing the forward leaves the tag binding to do its job in both cases.
    set fwd [expr {!(($N == 100 || $N == 98) && ($s & 4))}]
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

# item 10: a SUBMENU of an already-minted context menu `m`, for a `-menu`
# cascade. Returns the path, or {} when Tk refused.
#
# A SIBLING of ctx_menu_widget rather than a parameter on it, deliberately: that
# proc is shared by the trace and strip menus and hangs its widget off the
# TOPLEVEL by name, which is exactly wrong for a cascade (a submenu must be a
# child of its parent menu or Tk unposts it at the wrong moment). Extending the
# shared proc to do both would put a branch in the path items 7 and 8 depend on.
#
# No explicit destroy: ctx_menu_widget already destroyed the parent, and Tk
# destroys a menu's children with it, so `m` is always freshly empty here.
proc wviewer::ctx_menu_child {m name} {
  if {$m eq {} || ![winfo exists $m]} { return {} }
  set s $m.$name
  catch {destroy $s}
  if {[catch {menu $s -tearoff 0 -takefocus 0}]} { return {} }
  catch {
    $s configure -font AseLabelFont -background [ase::theme panel] \
                 -activebackground [ase::theme header]
  }
  return $s
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

# =============================================================================
# TABS  (doc/claude/specs/waveform_viewer_tabs.md)
# =============================================================================
#
# A tab is a MODEL, not a context (D1). The window keeps exactly ONE xschem
# context, one toplevel, one canvas and one loaded raw; a tab is another value
# of the Tcl model, painted by the `regenerate` that already exists. One
# xschem context per tab is not merely more expensive, it is unavailable:
# create_new_tab/switch_tab hardcode a tab's render target to
# save_xctx[0]->window (xinit.c), so a tab minted for THIS toplevel would draw
# onto the main schematic window's .drw, and doc/claude/specs/multi_window_detach.md
# ("A tab cannot belong to a second top-level") is still `proposed`.
#
# THE STASH (D2), and it is why this feature is small. Every per-view-content
# array -- layouts, mode, target, sharedx, gridshow, undo_hist, redo_hist,
# wavehl, cva, cvb, cvr -- KEEPS its session-token key and always describes the
# ACTIVE tab. The inactive tabs live FROZEN in `tabstash`. So not one line of
# existing viewer code changes its key: layout_for, with_edit, switch_ctx,
# token_for_canvas, current_token, regenerate, every *_at %W bindtag wrapper,
# every menubar -command that captured $token at build time, and every call
# from ase_window.tcl are all correct, untouched, by construction -- and a
# Direct Plot lands in the ACTIVE tab for free, because the arrays it writes
# ARE the active tab. The alternative (a <token>#N key space) would have needed
# a redirect at the head of ~40 procs, and a single missed one is a silent
# cross-tab write that no single-tab test could see.
#
# One frozen record:
#   {id N name S layout L mode M target T cva a cvb b cvr r
#    undo U redo R wavehl W view V}
# `id` is inert, stable and never reused: nothing behavioural reads it, it
# exists so a test can witness "the paste landed in the tab that was second"
# independently of "the tabs got reordered" (the `sdid` lesson).
#
# `view` (D6) is the TRANSIENT per-strip {x1 x2 y1 y2} read off the rects at
# freeze time and pushed back after the thaw's regenerate. Without it a tab
# switch would discard the pan/zoom the user made with the mouse -- the model
# still says {} = auto, so regenerate re-autozooms. It is never the model and
# never serialized (the `wavehl` shape), so it pins no auto axis and cannot
# copy strip 0's window over every strip under Shared X, which is exactly what
# landmine 50(c) forbids a range FOLD from doing.

# The frozen tab records of `token`, in bar order ({} when the window has none).
proc wviewer::tab_records {{token {}}} {
  variable tabstash
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists tabstash($token)]} { return {} }
  return $tabstash($token)
}

# How many tabs `token`'s window has (0 = not a viewer).
proc wviewer::tab_count {{token {}}} {
  return [llength [wviewer::tab_records $token]]
}

# The ACTIVE tab's index, or -1.
proc wviewer::tab_index {{token {}}} {
  variable curtab
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![info exists curtab($token)]} { return -1 }
  return $curtab($token)
}

# PURE: the index of tab `id` in `recs`, or -1. The id is the stable handle a
# log line carries; the index is what everything internal uses.
proc wviewer::tab_index_of_id {recs id} {
  set i 0
  foreach r $recs {
    if {[wviewer::dget $r id {}] eq $id} { return $i }
    incr i
  }
  return -1
}

# The ACTIVE tab's id, or {}.
proc wviewer::tab_id {{token {}}} {
  set i [wviewer::tab_index $token]
  set recs [wviewer::tab_records $token]
  if {$i < 0 || $i >= [llength $recs]} { return {} }
  return [wviewer::dget [lindex $recs $i] id {}]
}

# The display name of tab `id`, or {}.
proc wviewer::tab_name {id {token {}}} {
  set recs [wviewer::tab_records $token]
  set i [wviewer::tab_index_of_id $recs $id]
  if {$i < 0} { return {} }
  return [wviewer::dget [lindex $recs $i] name {}]
}

# PURE: which tab becomes active when the one at `idx` is removed from a list of
# `n` -- the neighbour to the RIGHT, or the LEFT when the closed tab was last.
# Callers pass the PRE-removal n.
proc wviewer::tab_index_after_close {idx n} {
  if {$n <= 1} { return 0 }
  if {$idx >= $n - 1} { return [expr {$n - 2}] }
  return $idx
}

# Read the LIVE per-strip ranges off the rects (D6). One 4-element sublist per
# graph rect, `{}` for a range the engine has no number for. Read-only
# (getprop), so no with_edit. Returns {} when the context refuses.
proc wviewer::tab_view_read {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  if {![wviewer::switch_ctx $token]} { return {} }
  set out {}
  set n 0
  catch {set n [xschem get graph_rects]}
  if {![string is integer -strict $n]} { return {} }
  for {set gi 0} {$gi < $n} {incr gi} {
    set row {}
    foreach tok {x1 x2 y1 y2} {
      set v {}
      catch {set v [xschem getprop rect 2 $gi $tok]}
      if {![string is double -strict $v]} { set v {} }
      lappend row $v
    }
    lappend out $row
  }
  return $out
}

# Push a `tab_view_read` result back onto the fresh rects after a regenerate
# (D6). Guarded on the strip count matching -- the same rect-vs-model 1:1 guard
# capture_live_graph_state and marker_changed carry, and a mismatch SKIPS
# silently rather than attaching one strip's window to another. Writes only
# ranges the engine can already hold in a read-only rect (landmine 19), so it
# needs with_edit only for the setprop gate.
proc wviewer::tab_view_apply {token view} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  if {![llength $view]} { return 0 }
  set n -1
  catch {set n [xschem get graph_rects]}
  if {![string is integer -strict $n] || $n != [llength $view]} { return 0 }
  set applied 0
  catch {
    wviewer::with_edit $token {
      set gi_ 0
      foreach row_ $view {
        foreach tok_ {x1 x2 y1 y2} v_ $row_ {
          if {$v_ eq {}} { continue }
          catch { xschem setprop -fast rect 2 $gi_ $tok_ $v_ }
        }
        incr gi_
      }
    }
    set applied 1
  }
  if {$applied} { catch {xschem redraw} }
  return $applied
}

# Freeze the LIVE arrays of `token` into a tab record. `base` is the record
# being replaced, so `id` and `name` survive a freeze/thaw round trip.
proc wviewer::tab_freeze {token base} {
  variable layouts
  variable mode; variable target
  variable cva; variable cvb; variable cvr
  variable undo_hist; variable redo_hist
  set rec $base
  dict set rec layout [wviewer::layout_for $token]
  dict set rec mode   [expr {[info exists mode($token)] ? $mode($token) : [wviewer::default_plot_mode]}]
  dict set rec target [expr {[info exists target($token)] ? $target($token) : 0}]
  foreach {k a} {cva cva cvb cvb cvr cvr} {
    dict set rec $k [expr {[info exists ::wviewer::${a}($token)] ? [set ::wviewer::${a}($token)] : 0}]
  }
  dict set rec undo   [expr {[info exists undo_hist($token)] ? $undo_hist($token) : {}}]
  dict set rec redo   [expr {[info exists redo_hist($token)] ? $redo_hist($token) : {}}]
  dict set rec wavehl [wviewer::wave_hilights $token]
  dict set rec view   [wviewer::tab_view_read $token]
  return $rec
}

# Thaw a tab record into the LIVE arrays. Does NOT regenerate -- the caller owns
# the single regenerate (the ONE-of-everything rule). Three things beyond the
# plain array writes, each of which the record cannot carry by itself:
#   - the sharedx and gridshow MENU MIRRORS are re-synced from the incoming
#     LAYOUT, which is their authority (the arrays exist only because Tk's
#     -variable needs a global);
#   - the engine CURSORS are re-driven, because one xctx means one pair of
#     cursors for every tab and the outgoing tab's would otherwise stay drawn;
#   - the readout bar follows its own mirror.
proc wviewer::tab_thaw {token rec} {
  variable layouts
  variable mode; variable target
  variable cva; variable cvb; variable cvr
  variable sharedx; variable gridshow
  variable undo_hist; variable redo_hist
  variable wavehl
  set lay [wviewer::dget $rec layout [dict create sharedx 0 graphs {}]]
  dict set layouts $token $lay
  set m [wviewer::resolve_mode single [wviewer::dget $rec mode {}]]
  if {$m eq {}} { set m [wviewer::default_plot_mode] }
  set mode($token)   $m
  set target($token) [wviewer::target_clamp [wviewer::dget $rec target 0] \
                        [llength [wviewer::dget $lay graphs {}]]]
  set undo_hist($token) [wviewer::dget $rec undo {}]
  set redo_hist($token) [wviewer::dget $rec redo {}]
  set wavehl($token)    [wviewer::dget $rec wavehl {}]
  set sharedx($token)   [expr {[wviewer::dget $lay sharedx 0] ? 1 : 0}]
  wviewer::sync_grid_mirror $token
  set cva($token) [expr {[wviewer::dget $rec cva 0] ? 1 : 0}]
  set cvb($token) [expr {[wviewer::dget $rec cvb 0] ? 1 : 0}]
  set cvr($token) [expr {[wviewer::dget $rec cvr 0] ? 1 : 0}]
  catch {wviewer::cursor_toggle $token 1}
  catch {wviewer::cursor_toggle $token 2}
  catch {wviewer::readout_show $token}
  return 1
}

# Everything a tab switch must ABANDON, because it addresses the outgoing tab's
# strips by INDEX and those indices are silently valid in the incoming one:
# a half-armed strip or trace drag, the marker selection, and the three modeless
# dialogs plus all three context menus (item 10 added the browser's), whose
# listboxes and row ids were built from the outgoing tab.
proc wviewer::tab_drop_transients {token} {
  variable windows
  catch {wviewer::strip_drag_reset $token}
  catch {wviewer::trace_drag_clear $token}
  catch {set ::wviewer::mmb($token) 0}
  catch {wviewer::trace_menu_unpost $token}
  catch {wviewer::strip_menu_unpost $token}
  # item 10: same argument as the two above — the browser menu's entries carry
  # the OUTGOING tab's row ids, and its grab must not survive the switch.
  # Item 11's SEA menu carries the outgoing tab's SIGNAL INDICES and is a
  # DISTINCT widget, so it needs the same treatment spelled separately.
  catch {wviewer::browser_menu_unpost $token}
  catch {wviewer::browser_sea_menu_unpost $token}
  # and the hover tooltip, which names a row INDEX into the outgoing tab's sea:
  # left up across a switch it would sit over the incoming tab claiming a name
  # that is not in it.
  catch {wviewer::browser_sea_tip_hide $token}
  catch {
    if {[wviewer::switch_ctx $token]} { xschem graph_marker select -none }
  }
  if {[dict exists $windows $token]} {
    set top [dict get $windows $token top]
    foreach w {wvadd wvdel wvaxes} { catch {destroy $top.$w} }
    array unset ::wviewer::axl ${token},*
    catch {unset ::wviewer::delmap($token)}
  }
  return 1
}

# Seed the tab bookkeeping of a freshly opened window: exactly ONE tab, holding
# whatever `open` has already put in the live arrays. Called from wviewer::open
# AFTER those arrays are seeded.
proc wviewer::tabs_init {token} {
  variable tabstash; variable curtab; variable tabseq
  set tabseq($token) 2
  set rec [wviewer::tab_freeze $token [dict create id 1 name {Tab 1}]]
  set tabstash($token) [list $rec]
  set curtab($token) 0
  return 1
}

# Drop every tab structure of `token` (called from forget).
proc wviewer::tabs_forget {token} {
  variable tabstash; variable curtab; variable tabseq
  catch {unset tabstash($token)}
  catch {unset curtab($token)}
  catch {unset tabseq($token)}
  return {}
}

# --- the tab bar (D7) --------------------------------------------------------
#
# A plain Tk frame of buttons, the shape xschem's own `.tabs` uses
# (setup_tabbed_interface, xschem.tcl) -- but NOT its code: those buttons'
# identity IS their -command string, which tab_ctx_cmd/tab_context_menu parse
# back out with `lindex ... 3` and prev_tab/next_tab scavenge with hardcoded
# `.tabs.x$i` + `winfo rootx`. Not a ttk::notebook either: a notebook manages
# its panes' geometry, and this "pane" is a single C-drawn X canvas that must
# not be reparented or duplicated. One canvas, N models.
#
# It lives on $top, OUTSIDE $wp, so strip_bindings -- which enumerates only
# [bind $wp] -- never sees it, and the existing `bind $top <Destroy>` %W guard
# already tolerates extra descendants. -takefocus 0 everywhere (the .tabs.x0
# precedent) and the select command ends in `focus <win_path>`, because
# autofocus_mainwindow defaults to 0 and keys only reach key_filter while the
# canvas holds focus.
#
# ⚠ It is PACKED ONLY WHILE THE WINDOW HAS >= 2 TABS -- the issue-0151
# precedent ("the active-strip marker only exists while there is a choice to
# make"). That is what keeps a one-tab viewer byte-identical to the shipped one,
# geometry included, so no shipped band or pixel assertion moves. The 1<->2
# transition goes through <Configure> -> configure_apply, which is the shipped
# window-resize path and already captures before it regenerates.

proc wviewer::tabbar_build {token top} {
  set f $top.wvtabs
  catch {destroy $f}
  frame $f -background [ase::theme panel] -takefocus 0
  return $f
}

# Rebuild the buttons, pack or unpack the bar, and refresh File > Close Tab.
# ONE function owns "the tab count changed", so the bar, the button states and
# the menu entry cannot disagree (the graph_marker_label_box doctrine).
proc wviewer::tabbar_refresh {token} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set top [dict get $windows $token top]
  set wp  [dict get $windows $token win_path]
  set f $top.wvtabs
  if {[catch {winfo exists $f} ex] || !$ex} { return 0 }
  foreach c [winfo children $f] { catch {destroy $c} }
  set recs [wviewer::tab_records $token]
  set cur  [wviewer::tab_index $token]
  set panel  [ase::theme panel]
  set header [ase::theme header]
  # ⚠ THE ACTIVE TAB NEEDS MORE THAN A BACKGROUND, and this is an EYEBALL
  # finding, not a review one: the first cut used `header` for the active tab
  # and `panel` for the rest, which are #e8e8e8 and #f2f2f2 -- TEN levels apart
  # in the ASE locked palette. On screen all three buttons were
  # indistinguishable and the user could not tell which tab they were on, with
  # 167 checks green (a `-background` leg would have passed: the two values DO
  # differ). So the active tab carries THREE simultaneous cues, all from the
  # locked palette: the white `table` background, the `accent` foreground, and
  # `raised` against the others' `flat`. TG-BAR asserts all three, so a future
  # edit cannot collapse it back to one near-invisible difference.
  set table  [ase::theme table]
  set accent [ase::theme accent]
  set i 0
  foreach r $recs {
    set id [wviewer::dget $r id $i]
    set on [expr {$i == $cur}]
    button $f.t$id -padx 6 -pady 0 -anchor nw -takefocus 0 \
      -font AseLabelFont -activebackground $header \
      -background  [expr {$on ? $table  : $header}] \
      -foreground  [expr {$on ? $accent : {black}}] \
      -relief      [expr {$on ? {raised} : {flat}}] \
      -text [wviewer::dget $r name "Tab $id"] \
      -command [list wviewer::select_tab_click $token $id]
    pack $f.t$id -side left
    incr i
  }
  button $f.add -padx 4 -pady 0 -takefocus 0 -text { + } \
    -font AseLabelFont -background $panel -activebackground $header \
    -command [list wviewer::new_tab $token]
  pack $f.add -side left
  catch {balloon $f.add {Create a new tab}}
  # pack / unpack. -before $top.drw is mandatory: the canvas is packed
  # -fill both -expand true, so anything packed AFTER it gets zero height.
  if {[llength $recs] >= 2} {
    if {[catch {pack info $f}]} { catch {pack $f -side top -fill x -before $top.drw} }
  } else {
    catch {pack forget $f}
  }
  # ... and the menu entry that says the same thing (D9a).
  set m $top.wvmenubar.file
  if {![catch {winfo exists $m} me] && $me} {
    catch {
      $m entryconfigure {Close Tab} \
        -state [expr {[llength $recs] >= 2 ? {normal} : {disabled}}]
    }
  }
  return 1
}

# A tab button was clicked: switch, then give the canvas the focus back.
proc wviewer::select_tab_click {token id} {
  wviewer::select_tab $id $token
  catch {focus [dict get $::wviewer::windows $token win_path]}
  return {}
}

# --- the three tab commands --------------------------------------------------

# Make tab `id` active. `token` {} = the viewer owning the current xschem ctx.
# Returns 1 on a switch, 0 when it was already active or nothing resolves.
#
# THE ORDERING IS THE CONTRACT and every step is load-bearing:
#   verified switch_ctx (landmine 17)
#   -> capture_live_view_state: regenerate does clear_drawing, and the SELECTION
#      lives only in the rect's hilight_wave/sel_waves tokens (landmine 50), so
#      a switch without the fold destroys the selection of the tab being left.
#      skip_ranges, per landmine 50(c) -- an unconditional range fold pins every
#      auto axis and, under Shared X, copies strip 0's window onto every strip's
#      MODEL permanently
#   -> freeze (which reads the live ranges into the record's transient `view`)
#   -> drop the transients that address the outgoing tab by index
#   -> thaw -> ONE regenerate -> push the incoming `view` back
# A tab switch is NAVIGATION: no push_undo (the set_plot_mode precedent).
proc wviewer::select_tab {id {token {}}} {
  variable windows
  variable tabstash; variable curtab
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    wviewer::echo "wviewer: no waveform viewer window" error
    return 0
  }
  set recs [wviewer::tab_records $token]
  set to [wviewer::tab_index_of_id $recs $id]
  if {$to < 0} {
    wviewer::echo "wviewer: no tab '$id'" error
    return 0
  }
  set from [wviewer::tab_index $token]
  if {$to == $from} { return 0 }
  if {![wviewer::switch_ctx $token]} {
    wviewer::echo "wviewer: cannot switch to the viewer window (context busy)" error
    return 0
  }
  wviewer::capture_live_view_state $token
  set recs [lreplace $recs $from $from \
              [wviewer::tab_freeze $token [lindex $recs $from]]]
  wviewer::tab_drop_transients $token
  set tabstash($token) $recs
  set curtab($token) $to
  set rec [lindex $recs $to]
  wviewer::tab_thaw $token $rec
  wviewer::regenerate $token
  wviewer::tab_view_apply $token [wviewer::dget $rec view {}]
  wviewer::tabbar_refresh $token
  wviewer::retitle $token
  catch {wviewer::status_refresh $token}
  wviewer::echo "wviewer: tab '[wviewer::dget $rec name $id]'"
  wviewer::log_action [list wviewer::select_tab $id $token]
  return 1
}

# Open a new tab and make it active. It starts with ONE empty strip -- exactly
# what clear_all leaves behind, so the tab reads as a graph window and the next
# plot has somewhere to land. The plot MODE and Shared X are INHERITED from the
# window's current tab (the clear_all precedent: a user working in multi-plot
# keeps working in multi-plot). Returns the new tab's id, or {}.
proc wviewer::new_tab {{token {}}} {
  variable windows
  variable tabstash; variable curtab; variable tabseq
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    wviewer::echo "wviewer: no waveform viewer window" error
    return {}
  }
  if {![wviewer::switch_ctx $token]} {
    wviewer::echo "wviewer: cannot switch to the viewer window (context busy)" error
    return {}
  }
  wviewer::capture_live_view_state $token
  set recs [wviewer::tab_records $token]
  set from [wviewer::tab_index $token]
  if {$from >= 0 && $from < [llength $recs]} {
    set recs [lreplace $recs $from $from \
                [wviewer::tab_freeze $token [lindex $recs $from]]]
  }
  if {![info exists tabseq($token)]} { set tabseq($token) [expr {[llength $recs] + 1}] }
  set id $tabseq($token)
  incr tabseq($token)
  set inherit_sx 0
  set inherit_grid [wviewer::grid_shown $token]
  if {$from >= 0 && $from < [llength $recs]} {
    set inherit_sx [wviewer::dget \
      [wviewer::dget [lindex $recs $from] layout {}] sharedx 0]
  }
  set lay [dict create sharedx $inherit_sx grid $inherit_grid \
                       graphs [list [wviewer::empty_graph]]]
  set rec [dict create id $id name "Tab $id" layout $lay \
             mode [wviewer::plot_mode $token] target 0 \
             cva 0 cvb 0 cvr [expr {[info exists ::wviewer::cvr($token)] \
                                     ? $::wviewer::cvr($token) : 0}] \
             undo {} redo {} wavehl {} view {}]
  lappend recs $rec
  wviewer::tab_drop_transients $token
  set tabstash($token) $recs
  set curtab($token) [expr {[llength $recs] - 1}]
  wviewer::tab_thaw $token $rec
  wviewer::regenerate $token
  wviewer::tabbar_refresh $token
  wviewer::retitle $token
  catch {wviewer::status_refresh $token}
  wviewer::echo "wviewer: new tab '[dict get $rec name]' ([llength $recs] tabs)"
  wviewer::log_action [list wviewer::new_tab $token]
  return $id
}

# Close tab `id` ({} = the active one). Returns 1 when a tab was closed.
#
# ⚠ D9a, USER RULING 2026-08-03: with only ONE tab this does NOTHING. It is a
# REFUSAL, not a fall-through to a window close -- Ctrl-W never closes a viewer
# window; Ctrl-Q, File > Close Window, the WM button and the programmatic
# wviewer::close are the only ways one dies. The refusal is SPOKEN (a key that
# silently does nothing reads as broken) and writes NO log line, because nothing
# changed -- the change-only rule.
proc wviewer::close_tab {{id {}} {token {}}} {
  variable windows
  variable tabstash; variable curtab
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    wviewer::echo "wviewer: no waveform viewer window" error
    return 0
  }
  set recs [wviewer::tab_records $token]
  set n [llength $recs]
  if {$n <= 1} {
    wviewer::echo "wviewer: only one tab - nothing to close"
    return 0
  }
  if {$id eq {}} { set id [wviewer::tab_id $token] }
  set idx [wviewer::tab_index_of_id $recs $id]
  if {$idx < 0} {
    wviewer::echo "wviewer: no tab '$id'" error
    return 0
  }
  if {![wviewer::switch_ctx $token]} {
    wviewer::echo "wviewer: cannot switch to the viewer window (context busy)" error
    return 0
  }
  # fold FIRST, unconditionally, before deciding anything: the live rect state
  # belongs to the ACTIVE tab, and in the not-the-active-tab branch below that
  # tab survives and must keep its selection (landmine 50). Wasted only in the
  # branch where the active tab is the one being discarded.
  wviewer::capture_live_view_state $token
  set cur  [wviewer::tab_index $token]
  set name [wviewer::dget [lindex $recs $idx] name "Tab $id"]
  if {$idx != $cur} {
    # ⚠ closing a tab that is NOT on screen (reachable from a replayed log line
    # carrying an explicit id, and from the menu once a rename exists). The
    # visible tab does not change, so there is no thaw and NO REGENERATE: the
    # canvas already shows the right model, and a needless clear_drawing here
    # would throw away the live pan/zoom for nothing.
    set recs [lreplace $recs $idx $idx \
                [wviewer::tab_freeze $token [lindex $recs $idx]]]
    set recs [lreplace $recs $idx $idx]
    set tabstash($token) $recs
    set curtab($token) [expr {$idx < $cur ? $cur - 1 : $cur}]
    wviewer::tabbar_refresh $token
    wviewer::echo "wviewer: closed tab '$name' ([llength $recs] left)"
    wviewer::log_action [list wviewer::close_tab $id $token]
    return 1
  }
  set to [wviewer::tab_index_after_close $idx $n]
  set recs [lreplace $recs $idx $idx]
  wviewer::tab_drop_transients $token
  set tabstash($token) $recs
  set curtab($token) $to
  set rec [lindex $recs $to]
  wviewer::tab_thaw $token $rec
  wviewer::regenerate $token
  wviewer::tab_view_apply $token [wviewer::dget $rec view {}]
  wviewer::tabbar_refresh $token
  wviewer::retitle $token
  catch {wviewer::status_refresh $token}
  wviewer::echo "wviewer: closed tab '$name' ([llength $recs] left)"
  wviewer::log_action [list wviewer::close_tab $id $token]
  return 1
}

# --- copy / paste of TRACES (D12-D17) ----------------------------------------
#
# Copy is a TRACE-level operation, never a strip-level one. It copies the four
# trace keys {expr name vec color} plus, per item, the SOURCE STRIP INDEX -- and
# that index is the whole of what "keep their separateness" needs, because the
# groups are derived from it. It must NOT copy graph dicts: those carry `auto`,
# `markers`, `hilight_wave`/`sel_waves` and axis ranges, all of which are
# meaningless or actively harmful in another strip.

# PURE: clipboard items -> GROUPS, one per distinct source strip, in source
# order, each an ordered list of trace dicts. The grouping IS the separateness.
proc wviewer::clip_groups {items} {
  set order {}
  array set byg {}
  foreach it $items {
    set gi [wviewer::dget $it gi {}]
    set tr [wviewer::dget $it tr {}]
    if {$gi eq {} || ![string is integer -strict $gi] || ![llength $tr]} { continue }
    if {![info exists byg($gi)]} { set byg($gi) {}; lappend order $gi }
    lappend byg($gi) $tr
  }
  set out {}
  foreach gi $order { lappend out $byg($gi) }
  return $out
}

# PURE: where `ngroups` pasted groups land. The plan_plot shape, and the one
# place the landing policy is expressed.
#
#  multi  -- one group per strip: reuse empty non-auto strips first, lowest
#            index first (empty_graph_indices, the issue-0171 follow-up rule),
#            and APPEND the shortfall at the bottom.
#  single -- every group flattens into the clamped, non-auto target strip.
#
# ⚠ A PASTE APPENDS; IT DOES NOT FRONT-INSERT. plot_signals' multi arm grows the
# stack UPWARD and lays a batch out newest-first, because a plot batch is "the
# newest thing you asked for" -- and it therefore owes the +nnew shift of the
# stored target AND of the highlight set. A paste is a copy of a layout fragment
# and must READ THE SAME WAY IT DID in the source tab, so it appends and owes
# neither shift. The deviation is deliberate; do not "fix" it. (Reused empties
# keep indices < ngraphs and appended strips take indices >= ngraphs, so group
# order survives either way.)
proc wviewer::plan_paste {mode ngraphs target ngroups {auto -1} {empties {}}} {
  if {$ngroups <= 0} { return [dict create new 0 sites {}] }
  set free {}
  foreach gi $empties {
    if {[string is integer -strict $gi] && $gi >= 0 && $gi < $ngraphs \
        && $gi != $auto && [lsearch -exact $free $gi] < 0} {
      lappend free $gi
    }
  }
  set free [lsort -integer $free]
  if {$mode eq {multi}} {
    set reuse [lrange $free 0 [expr {$ngroups - 1}]]
    set nreuse [llength $reuse]
    set new [expr {$ngroups - $nreuse}]
    set sites {}
    for {set k 0} {$k < $ngroups} {incr k} {
      if {$k < $nreuse} {
        lappend sites [lindex $reuse $k]
      } else {
        lappend sites [expr {$ngraphs + $k - $nreuse}]
      }
    }
    return [dict create new $new sites $sites]
  }
  set gi [wviewer::target_clamp $target $ngraphs]
  set new 0
  if {$ngraphs <= 0 || ($auto >= 0 && $gi == $auto)} {
    if {[llength $free]} { set gi [lindex $free 0] } else { set gi $ngraphs; set new 1 }
  }
  set sites {}
  for {set k 0} {$k < $ngroups} {incr k} { lappend sites $gi }
  return [dict create new $new sites $sites]
}

# PURE: the colour every pasted trace gets, as a list parallel to `groups`.
#
# D14: a pasted trace KEEPS its source colour when that colour is not already
# used in the strip it lands on, else it takes the next unused palette entry.
# Keeping it is what makes a trace recognisable across tabs -- the point of
# copying it -- while keeping it blindly puts two indistinguishable traces on
# one strip, precisely the failure issue 0153 fixed. The walk is per LANDING
# strip and the `used` set GROWS as the group is placed, so two source traces
# that shared a colour and land together still separate.
proc wviewer::paste_colors {graphs groups sites} {
  array set used {}
  set out {}
  foreach grp $groups site $sites {
    if {![info exists used($site)]} {
      set used($site) [wviewer::graph_colors [lindex $graphs $site]]
    }
    set row {}
    foreach tr $grp {
      set c [wviewer::dget $tr color {}]
      if {$c eq {} || [lsearch -exact $used($site) $c] >= 0} {
        set c [wviewer::first_unused_color $used($site)]
      }
      lappend used($site) $c
      lappend row $c
    }
    lappend out $row
  }
  return $out
}

# PURE: append every group's traces to its landing strip. `graphs` must ALREADY
# carry the strips `plan_paste` asked for (the caller appends them), because
# `sites` indexes that extended list.
#
# ⚠ This is NOT move_traces_in_graphs and must not become it: that proc's
# `- $done($gi)` per-source index adjustment (landmine 49(a)) exists only
# because a MOVE removes from its source. A paste removes from nothing.
#
# D15: a destination that had NO traces gets its ranges blanked back to auto,
# because capture_live_view_state has just frozen whatever window was last
# fitted and a uA trace dropped into a 0-2 V window draws off-screen and reads
# as "the paste failed" (landmine 34(a)). A destination that already holds
# traces keeps its window -- and a second group landing on the same strip in
# single mode sees the first group's traces, so it correctly does not re-blank.
proc wviewer::paste_traces_in_graphs {graphs groups sites colors} {
  foreach grp $groups site $sites cols $colors {
    if {![string is integer -strict $site] || $site < 0 || $site >= [llength $graphs]} {
      continue
    }
    set D [lindex $graphs $site]
    set trs [wviewer::dget $D traces {}]
    set was_empty [expr {[llength $trs] == 0}]
    foreach tr $grp col $cols {
      if {$col ne {}} { dict set tr color $col }
      lappend trs $tr
    }
    dict set D traces $trs
    if {$was_empty} {
      foreach k {x1 x2 y1 y2} { dict set D $k {} }
    }
    set graphs [lreplace $graphs $site $site $D]
  }
  return $graphs
}

# The current clipboard (test seam).
proc wviewer::clipboard {} {
  variable clip
  return $clip
}

# Ctrl-C: copy the CURRENT trace selection. Mutates no model, so it takes no
# undo point, does not regenerate and writes NO replayable command line -- its
# record is the echo line, which reaches BOTH channels and so satisfies R6.
#
# Three steps are load-bearing and in this order:
#   VERIFIED switch_ctx  -- `selected_waves` only catches its OWN switch, so a
#     refused one would read a FOREIGN window's rects;
#   capture_live_view_state -- the selection lives ONLY on the rect until it is
#     folded (landmine 50);
#   selection_pairs -- the one shared NODE->MODEL fold (landmine 34).
proc wviewer::copy_traces {{token {}}} {
  variable windows
  variable clip
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    wviewer::echo "wviewer: no waveform viewer window" error
    return 0
  }
  if {![wviewer::switch_ctx $token]} {
    wviewer::echo "wviewer: cannot switch to the viewer window (context busy)" error
    return 0
  }
  wviewer::capture_live_view_state $token
  set wp [dict get $windows $token win_path]
  set pairs [wviewer::selection_pairs $wp]
  if {![llength $pairs]} {
    # ⚠ the clipboard is LEFT UNTOUCHED: a failed copy must never destroy a
    # good one.
    wviewer::echo "wviewer: nothing selected to copy"
    return 0
  }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set items {}
  set strips {}
  foreach p $pairs {
    lassign $p gi ti
    set G [lindex $gs $gi]
    set tr [lindex [wviewer::dget $G traces {}] $ti]
    if {![llength $tr]} { continue }
    lappend items [dict create gi $gi tr $tr]
    if {[lsearch -exact $strips $gi] < 0} { lappend strips $gi }
  }
  if {![llength $items]} {
    wviewer::echo "wviewer: nothing selected to copy"
    return 0
  }
  set rawf {}; set simt {}
  catch {set rawf [xschem raw rawfile]}
  catch {set simt [xschem raw sim_type]}
  set clip [dict create from [list $token [wviewer::tab_id $token]] \
                       raw [list $rawf $simt] items $items]
  wviewer::echo "wviewer: copied [llength $items] trace(s) from [llength $strips] strip(s)"
  return [llength $items]
}

# Ctrl-V: paste the clipboard into the ACTIVE tab.
#
# ONE of everything (D17, landmines 46(c)/49(b)): one verified switch_ctx, one
# capture_live_view_state, one push_undo, one regenerate, one fully-resolved log
# line carrying the descriptors ACTUALLY pasted.
proc wviewer::paste_traces {{token {}}} {
  variable windows
  variable clip
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} {
    wviewer::echo "wviewer: no waveform viewer window" error
    return 0
  }
  set items [wviewer::dget $clip items {}]
  if {![llength $items]} {
    wviewer::echo "wviewer: clipboard is empty"
    return 0
  }
  if {![wviewer::switch_ctx $token]} {
    wviewer::echo "wviewer: cannot switch to the viewer window (context busy)" error
    return 0
  }
  set groups [wviewer::clip_groups $items]
  if {![llength $groups]} {
    wviewer::echo "wviewer: clipboard is empty"
    return 0
  }
  wviewer::capture_live_view_state $token
  set gs   [dict get [wviewer::layout_for $token] graphs]
  set mode [wviewer::plot_mode $token]
  set auto [wviewer::auto_graph_index $token]
  set plan [wviewer::plan_paste $mode [llength $gs] \
              [wviewer::target_index $token] [llength $groups] $auto \
              [wviewer::empty_graph_indices $gs $auto]]
  set nnew [dict get $plan new]
  set sites [dict get $plan sites]
  set ext $gs
  for {set k 0} {$k < $nnew} {incr k} { lappend ext [wviewer::empty_graph] }
  # D16: a viewer trace carries only a NAME -- graph_props emits no `rawfile=`
  # or `sim_type=` -- so every trace resolves against THIS context's raw. Inside
  # one window (the R5 case) that is the same raw the copy came from and there
  # is nothing to do. Across windows it is a NAME REBIND, so: re-materialise
  # every expression trace the way `restore` does, warn about names the
  # destination raw does not have, and ⚠ RENAME an expression vector whose name
  # is already taken here -- otherwise `raw_add_vector` recomputes the
  # DESTINATION's own vector in place and silently changes a trace already on
  # screen.
  set same_win [expr {[lindex [wviewer::dget $clip from {}] 0] eq $token}]
  set missing {}
  set g 0
  foreach grp $groups {
    set t 0
    foreach tr $grp {
      set ex  [wviewer::dget $tr expr {}]
      set vec [wviewer::dget $tr vec {}]
      set multi [expr {[llength [regexp -all -inline {\S+} $ex]] > 1}]
      if {$vec ne {} && $multi} {
        if {!$same_win} {
          set idx -1
          catch {set idx [xschem raw index $vec]}
          if {$idx >= 0} {
            set vec [wviewer::auto_expr_name $token]
            dict set tr vec $vec
            set grp [lreplace $grp $t $t $tr]
            set groups [lreplace $groups $g $g $grp]
          }
        }
        catch {xschem raw add $vec $ex}
      } elseif {$vec ne {} && !$same_win} {
        set idx -1
        catch {set idx [xschem raw index $vec]}
        if {$idx < 0 && [lsearch -exact $missing $vec] < 0} { lappend missing $vec }
      }
      incr t
    }
    incr g
  }
  set colors [wviewer::paste_colors $ext $groups $sites]
  # AFTER the capture, BEFORE the mutation: one undo point for the whole paste,
  # so `u` takes it all back rather than one trace at a time.
  wviewer::push_undo $token
  wviewer::set_graphs $token \
    [wviewer::paste_traces_in_graphs $ext $groups $sites $colors]
  wviewer::regenerate $token
  wviewer::tabbar_refresh $token
  if {[llength $missing]} {
    wviewer::echo "wviewer: [llength $missing] vector(s) not in this window's raw: [join $missing { }]"
  }
  set ntr 0
  foreach grp $groups { incr ntr [llength $grp] }
  set nsite [llength [lsort -unique $sites]]
  wviewer::echo "wviewer: pasted $ntr trace(s) into $nsite strip(s)"
  # the payload is in the LINE, not a clipboard reference, so a replay does not
  # depend on live session state (landmine 49(b)'s normalised-arguments rule).
  wviewer::log_action [list wviewer::paste_payload $groups $sites $colors $token]
  return $ntr
}

# The replay form of a paste: land an explicit payload, no clipboard involved.
proc wviewer::paste_payload {groups sites colors {token {}}} {
  variable windows
  set token [wviewer::resolve_token $token]
  if {$token eq {} || ![dict exists $windows $token]} { return 0 }
  if {![wviewer::switch_ctx $token]} { return 0 }
  wviewer::capture_live_view_state $token
  set gs [dict get [wviewer::layout_for $token] graphs]
  set need 0
  foreach s $sites { if {$s >= $need} { set need [expr {$s + 1}] } }
  set ext $gs
  while {[llength $ext] < $need} { lappend ext [wviewer::empty_graph] }
  wviewer::push_undo $token
  wviewer::set_graphs $token \
    [wviewer::paste_traces_in_graphs $ext $groups $sites $colors]
  wviewer::regenerate $token
  return 1
}

# --- the %W wrappers the WaveViewer bindtag calls ----------------------------
# Every one resolves its token from the WIDGET, never from the current xschem
# context: the bindtag is process-global.

proc wviewer::new_tab_at {W} {
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { return {} }
  if {[catch {wviewer::new_tab $tok} e]} {
    wviewer::echo "wviewer: new tab refused: $e" error
  }
  return {}
}

proc wviewer::close_tab_at {W} {
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { return {} }
  if {[catch {wviewer::close_tab {} $tok} e]} {
    wviewer::echo "wviewer: close tab refused: $e" error
  }
  return {}
}

proc wviewer::copy_traces_at {W} {
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { return {} }
  if {[catch {wviewer::copy_traces $tok} e]} {
    wviewer::echo "wviewer: copy refused: $e" error
  }
  return {}
}

proc wviewer::paste_traces_at {W} {
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { return {} }
  if {[catch {wviewer::paste_traces $tok} e]} {
    wviewer::echo "wviewer: paste refused: $e" error
  }
  return {}
}

proc wviewer::close_window_at {W} {
  set tok [wviewer::token_for_canvas $W]
  if {$tok eq {}} { return {} }
  set n [wviewer::tab_count $tok]
  if {[catch {wviewer::close $tok} e]} {
    wviewer::echo "wviewer: close refused: $e" error
    return {}
  }
  wviewer::echo "wviewer: closed the waveform viewer ($n tab(s))"
  wviewer::log_action [list wviewer::close $tok]
  return {}
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
  # File menu (doc/claude/specs/waveform_viewer_tabs.md D11). The shipped single
  # `Close  Ctrl+W` entry (which killed the WINDOW) is replaced by the tab pair:
  # leaving it would contradict both the key and D9a. Accelerator labels are
  # inert display strings -- Tk does not dispatch them, and an rc that remaps the
  # WaveViewer bindtag changes the key, not this label.
  # ⚠ No new top-level cascade: test_wave_viewer G2 asserts the cascade set is
  # exactly {File View Graph Cursors Options}, and a `Tabs` menu would buy
  # nothing a File entry does not.
  $mb.file add command -label {New Tab} -accelerator Ctrl+N \
    -command [list wviewer::new_tab $token]
  # -state is refreshed by tabbar_refresh, the ONE owner of "the tab count
  # changed", so the bar, the buttons and this entry cannot disagree.
  $mb.file add command -label {Close Tab} -accelerator Ctrl+W -state disabled \
    -command [list wviewer::close_tab {} $token]
  $mb.file add command -label {Close Window} -accelerator Ctrl+Q \
    -command [list wviewer::close $token]
  $mb.file add separator
  $mb.file add command -label {Copy Traces} -accelerator Ctrl+C \
    -command [list wviewer::copy_traces $token]
  $mb.file add command -label {Paste Traces} -accelerator Ctrl+V \
    -command [list wviewer::paste_traces $token]
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
  # signal-browser item 8: the menu twin of the Ctrl-B bindtag default (Ctrl-L
  # until TWO-PANE item 16, R9). A checkbutton, not a command, because this is a
  # STATE -- and its variable is PUSHED by sync_browser_mirror on every change
  # rather than polled by a -postcommand, so it cannot go stale when the key is
  # used (the Grid entry's rule). ⚠ `-label {Signal Browser} -accelerator Ctrl+B`
  # must stay ADJACENT on one source line: test_wave_grid GH3 greps this proc's
  # body for exactly that string, and it must agree with the guide's
  # data-accel (GH3/GH4 compare them).
  $mb.view add checkbutton -label {Signal Browser} -accelerator Ctrl+B \
    -variable ::wviewer::browsershow($token) \
    -command [list wviewer::browser_from_menu $token]
  # signal-browser item 11: the menubar twin of the Shift-E bindtag default and
  # of the browser's RMB entry. It acts on the tree's SELECTION, because a
  # menubar entry has no pointer position to resolve. No new top-level cascade:
  # test_wave_viewer G2 pins the cascade set to {File View Graph Cursors
  # Options}. ⚠ `-label {Descend to here} -accelerator E` must stay ADJACENT on
  # one source line: test_wave_grid GH3 greps this proc's body for exactly that
  # string.
  $mb.view add command -label {Descend to here} -accelerator E \
    -command [list wviewer::browser_descend_here $token]
  # The Calculator (doc/claude/specs/calculator.md) belongs under Tools by
  # Cadence convention, but G2 asserts this menubar's cascade set is exactly
  # {File View Graph Cursors Options} and a whole cascade for one launcher
  # would buy nothing. A View entry keeps the assertion true.
  $mb.view add separator
  $mb.view add command -label {Calculator...} -command calc::open
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
  # item 7: the plot DESTINATION, the menu route to the same per-window setting
  # the Add Trace dropdown writes.
  # ⚠ PLAIN COMMANDS, NOT RADIOBUTTONS, and that is not a style choice: Tk
  # writes a radiobutton's `-variable` BEFORE it fires `-command`, so
  # set_plot_dest would always see the new value already in place, find "no
  # change" and never write its replayable log line. The `gridshow` mirror
  # comment documents the same trap.
  menu $mb.options.plotdest -tearoff 0 -takefocus 0 \
    -font AseLabelFont -background $panel -activebackground $header
  foreach lbl [wviewer::dest_labels] {
    $mb.options.plotdest add command -label $lbl \
      -command [list wviewer::set_plot_dest [wviewer::dest_norm $lbl] $token]
  }
  $mb.options add cascade -label {Plot Destination} -menu $mb.options.plotdest
  $top configure -menu $mb
}
