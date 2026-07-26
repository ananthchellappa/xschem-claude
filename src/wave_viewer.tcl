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
#     set_modify(-1)) and on FocusIn.
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
# add`, D5), Delete... (listbox of graphs+traces — canvas legend click-
# select has no C hit-test API, receipts/11), Axes... (ranges + log
# toggles), Shared X Axis. All dialogs = ase::ui scaffold (ESC-cancel by
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
# Pure Tcl, procs only at source time (safe under --nogui); ciw_echo only
# under has_x. TIP-278: `variable` declarations, absolute names.

# Initial plot mode of a NEWLY OPENED viewer window (single|multi). Read
# LAZILY (at open time) so a `--script` rc — cadence_style_rc, headless
# tests — can still set it; once a window is open its own per-window mode is
# the authority. Invalid values fall back to `single`.
set_ne wviewer_plot_mode single

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
  # keysyms of the waves_callback key set (a b s m t A B) — forwarded ONLY
  # over a graph; outside graphs these are editor verbs (m=move, t=text ...)
  # and must do nothing, silently.
  variable graphkeys {97 98 115 109 116 65 66}
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
  # item 18 (graph-fills-win): <Configure> refit bookkeeping, per session token.
  # cfgafter = the pending `after idle` id (coalesces resize storms); fillwh =
  # the canvas pixel size {W H} the last regenerate filled at (so on_configure
  # re-fills ONLY when the size actually changed). Cleaned on forget.
  variable cfgafter; array set cfgafter {}
  variable fillwh;   array set fillwh {}
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
  variable mode; variable target
  variable axl; variable delmap
  variable cfgafter; variable fillwh
  if {[dict exists $windows $token]} {
    dict unset graphbb [dict get $windows $token win_path]
    dict unset windows $token
  }
  dict unset layouts $token
  catch {unset cva($token)}
  catch {unset cvb($token)}
  catch {unset cvr($token)}
  catch {unset sharedx($token)}
  catch {unset mode($token)}
  catch {unset target($token)}
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
  variable cva; variable cvb; variable cvr; variable sharedx
  variable mode; variable target
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
  xschem load_new_window -window {}
  set wp [xschem get current_win_path]
  # derive the toplevel from win_path (.xN.drw -> .xN) rather than
  # `xschem get top_path`, which reports {} under the tabbed interface
  regsub {\.drw$} $wp {} top
  if {$top eq {}} { set top . }
  # D1: readonly for the window's life — modified becomes unsettable, so no
  # save prompt can ever appear on close
  xschem set readonly 1
  # item 18 (D1): grid/origin OFF for THIS window only (per-ctx C flag, NOT the
  # global draw_grid — normal schematic windows keep their grid). Set once and
  # never cleared; alloc_xschem_data zeroes it for every other ctx. The window
  # now reads as a graph, not a schematic.
  xschem set no_grid 1
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
  # item 12: fresh per-window model + cursor mirrors (forget cleared any
  # previous window's state for this token)
  if {![dict exists $layouts $token]} {
    dict set layouts $token [dict create sharedx 0 graphs {}]
  }
  set cva($token) 0
  set cvb($token) 0
  set cvr($token) 0
  set sharedx($token) 0
  # issue 0151: the config var seeds THIS window's mode and nothing else —
  # from here on the per-window value is the authority (restore overwrites
  # both right after, when a state dict carries them)
  set mode($token) [wviewer::default_plot_mode]
  set target($token) 0
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

# Switch to the viewer's context and run `script` at global level (the View
# menu wrappers — navigation verbs are not readonly-gated).
proc wviewer::in_ctx {token script} {
  variable windows
  if {![dict exists $windows $token]} { return }
  xschem new_schematic switch [dict get $windows $token win_path]
  uplevel #0 $script
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

# Clamp a stored target index into a layout of `n` graphs. Out of range, a
# non-integer or an empty layout all collapse to 0 — the target is stored raw
# and clamped on every read, so deleting strips can never dangle it.
proc wviewer::target_clamp {gi n} {
  if {$n <= 0} { return 0 }
  if {![string is integer -strict $gi] || $gi < 0} { return 0 }
  if {$gi >= $n} { return [expr {$n - 1}] }
  return $gi
}

# THE landing policy. Given the mode, the current strip count, the stored
# target, how many signals one plot gesture carries and the index of the
# tool-owned auto-plot strip (-1 = none), return
#   {new <how many strips to append> targets {<strip index per signal>}}
# single -> everything into the (clamped) target; a strip is created ONLY
#           when the stack is empty OR the target resolved to the AUTO-PLOT
#           strip, and the signals go into the created one.
# multi  -> one NEW strip per signal, appended AFTER the existing stack, in
#           pick order; the target is irrelevant and is not moved.
# Zero signals is a no-op in both modes (an empty Direct Plot gesture must
# leave the raised viewer exactly as it was).
#
# WHY the auto-plot strip is excluded: it is REBUILT (traces cleared and
# re-added) after every successful run — ase::ui::auto_plot, item 13's
# always-replace contract. Landing hand-picked Direct-Plot traces there would
# silently destroy them at the next run, and it would break the shipped
# invariant that Direct-Plot graphs and the auto graph never touch each other
# (doc/claude/specs/waveform_viewer.md, item 13 notes).
proc wviewer::plan_plot {mode ngraphs target n {auto -1}} {
  if {$n <= 0} { return [dict create new 0 targets {}] }
  if {$mode eq {multi}} {
    set t {}
    for {set k 0} {$k < $n} {incr k} { lappend t [expr {$ngraphs + $k}] }
    return [dict create new $n targets $t]
  }
  set gi [wviewer::target_clamp $target $ngraphs]
  if {$ngraphs <= 0 || ($auto >= 0 && $gi == $auto)} {
    # nothing usable to land in: append ONE strip and use it
    set gi $ngraphs
    set t {}
    for {set k 0} {$k < $n} {incr k} { lappend t $gi }
    return [dict create new 1 targets $t]
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
  set G [dict replace [lindex $gs $gi] traces {}]
  wviewer::set_graphs $token [lreplace $gs $gi $gi $G]
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
  set plan [wviewer::plan_plot $mode [llength $gs] \
                               [wviewer::target_index $token] $n \
                               [wviewer::auto_graph_index $token]]
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
proc wviewer::graph_props {G {active 0}} {
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
  return "flags=graph\ny1=$y1\ny2=$y2\nypos1=0\nypos2=2\ndivy=5\nsubdivy=1\nunity=1\nx1=$x1\nx2=$x2\ndivx=5\nsubdivx=1\nxlabmag=1.0\nylabmag=1.0\nlegendmag=1.0\nnode=\"$node\"\ncolor=\"$color\"\ndataset=-1\nunitx=1\nlogx=$logx\nlogy=$logy\n$act"
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
        [wviewer::graph_props $G_ [expr {$gi_ == $act_gi}]]
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
  set gs [dict get [wviewer::layout_for $token] graphs]
  set mode [wviewer::plot_mode $token]
  set plan [wviewer::plan_plot $mode [llength $gs] \
                               [wviewer::target_index $token] [llength $exprs] \
                               [wviewer::auto_graph_index $token]]
  if {![llength $colors]} {
    # `gs` is the PRE-batch strip list, which is what plan_colors expects
    set colors [wviewer::plan_colors $gs $mode [dict get $plan targets]]
  }
  for {set k 0} {$k < [dict get $plan new]} {incr k} {
    wviewer::add_graph $token
  }
  # single-plot had to CREATE its landing strip (empty stack, or the target
  # was the tool-owned auto-plot strip): that strip becomes the target, so the
  # next gesture accumulates there instead of appending yet another strip.
  # multi-plot never moves the target (spec §3.3).
  if {$mode ne {multi} && [dict get $plan new] > 0} {
    wviewer::set_target_strip [lindex [dict get $plan targets] 0] $token
  }
  set errs {}
  foreach ex $exprs gi [dict get $plan targets] col $colors {
    set err [wviewer::add_trace $token $gi $ex {} $col]
    if {$err ne {}} { lappend errs [list $ex $err] }
  }
  return $errs
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
proc wviewer::readout_refresh {token} {
  variable windows
  variable cva; variable cvb
  if {![dict exists $windows $token]} { return }
  set top [dict get $windows $token top]
  set bar $top.wvreadout
  if {[catch {winfo exists $bar} e] || !$e} { return }
  set wp [dict get $windows $token win_path]
  xschem new_schematic switch $wp
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
# was rejected (D1): plain wheel there is a HORIZONTAL body pan (callback.c
# :1157-1168) and Ctrl+wheel is hard-pinned to CANVAS zoom (callback.c:4417) —
# both contradict the user's ask. Pure Tcl setprop/getprop keeps it
# deterministic (item-17 lesson: witness a synchronous state write, not a
# gesture). RMB stays on the C engine (btn3_filter) — the engine already does
# graph x-zoom-to-box and leaves the canvas pinned.

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
proc wviewer::wheel_zoom {token dir gi {px {}} {py {}}} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set gs [dict get [wviewer::layout_for $token] graphs]
  set n [llength $gs]
  set f [expr {($dir eq {up} || $dir eq {in}) ? 0.8 : 1 / 0.8}]
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
#   ctrl           -> GRAPH zoom about center (wviewer::wheel_zoom): X on every
#                    graph, Y on the POINTED graph only (issue 0144).
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
      # (0146); writes + regenerates itself
      wviewer::wheel_zoom $token $dir $gi $px $py
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
# selected traces and/or whole graphs from the model + regenerate. Chosen
# selection model for v1: canvas-legend click-select has no C hit-test API
# (receipts/11: rect descriptors carry no coordinates) — the listbox is
# the honest v1.
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

proc wviewer::delete_ok {token} {
  variable windows
  variable delmap
  if {![dict exists $windows $token]} { return }
  set w [dict get $windows $token top].wvdel
  if {![winfo exists $w]} { return }
  set map {}
  if {[info exists delmap($token)]} { set map $delmap($token) }
  set delg {}
  set delt [dict create]
  foreach idx [$w.items curselection] {
    set ent [lindex $map $idx]
    if {[lindex $ent 0] eq {graph}} {
      lappend delg [lindex $ent 1]
    } elseif {[lindex $ent 0] eq {trace}} {
      dict lappend delt [lindex $ent 1] [lindex $ent 2]
    }
  }
  set out {}
  set gi 0
  foreach G [dict get [wviewer::layout_for $token] graphs] {
    if {[lsearch -exact $delg $gi] >= 0} { incr gi; continue }
    if {[dict exists $delt $gi]} {
      set trs [dict get $G traces]
      foreach ti [lsort -integer -decreasing [dict get $delt $gi]] {
        set trs [lreplace $trs $ti $ti]
      }
      set G [dict replace $G traces $trs]
    }
    lappend out $G
    incr gi
  }
  wviewer::set_graphs $token $out
  catch {unset delmap($token)}
  destroy $w
  wviewer::regenerate $token
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
  set G [lindex $gs $gi]
  foreach en {x1 x2 y1 y2} {
    set v [string trim [$w.$en get]]
    if {$v ne {} && ![string is double -strict $v]} {
      $w.err configure -text "not a number: $en '$v' (blank = auto)"
      return
    }
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
    catch {destroy .ctxmenu}                          ;# mirror the editor bind
    set fwd 1
  } elseif {$N == 102 || $N == 90 || ($N == 122 && ($s & 4))} {
    set fwd 1
  } elseif {[lsearch -exact $graphkeys $N] >= 0 && [wviewer::over_graph $W]} {
    set fwd 1
  }
  if {$fwd} {
    xschem callback $W $T $x $y $N 0 0 $s
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
proc wviewer::btn3_filter {W T x y b s} {
  if {$T == 4} { catch {focus $W} }                   ;# ButtonPress focuses
  xschem callback $W $T $x $y 0 $b 0 $s
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
  bind $wp <KeyPress>   {wviewer::key_filter %W %T %x %y %N %K %s}
  bind $wp <KeyRelease> {wviewer::key_filter %W %T %x %y %N %K %s}
  bind $wp <ButtonPress-3>   {wviewer::btn3_filter %W %T %x %y 3 %s}
  bind $wp <ButtonRelease-3> {wviewer::btn3_filter %W %T %x %y 3 %s}
  # issue 0151: clicking a strip makes it the TARGET (where signals sent from
  # the schematic land in single-plot mode). <ButtonPress-1> is MORE SPECIFIC
  # than the kept generic <Button>, so binding it would otherwise swallow the
  # C engine's press (cursor grab / graph pan) — hence the manual forward,
  # byte-for-byte the generic body from set_bindings (xschem.tcl), and the
  # trailing `break`: exactly one forward whether the generic binding lives on
  # this widget's tag or the toplevel's. The re-target runs FIRST so a press
  # that starts a cursor drag still lands on the strip it was aimed at.
  bind $wp <ButtonPress-1> {
    wviewer::click_target %W %x %y
    focus %W
    xschem callback %W %T %x %y 0 %b 0 %s
    break
  }
  bind $wp <Double-Button-1> {break}                  ;# D9: no graph props dlg
  bind $wp <Double-Button-2> {break}
  bind $wp <Double-Button-3> {break}
  # issue 0149: kill the canvas-only mouse gestures. Button-2 (MMB) is the
  # schematic PAN gesture — waves_selected EXPLICITLY skips Button-2 press /
  # release / drag-motion so it can never be graph-routed, and handle_button_press
  # calls start_pan_logged(): in the viewer that slides the whole tiled graph
  # stack around a bigger canvas and exposes blank space. Ctrl+MMB is the
  # pin-type edit chord (a mutating action, i.e. a readonly modal). Shift+B1 and
  # Alt+B1 are likewise canvas-only (waves_selected skips Shift+B1; Alt sets
  # SET_MODMASK) and mean rubber-band/copy-drag and unselect-at-pointer — pure
  # schematic-object gestures with no graph counterpart. All swallowed; plain
  # Button-1 still reaches the C engine (cursor drag / graph pan). The bands tile
  # the whole viewport (band_geometry), so a plain click always lands on a graph.
  foreach seq {<ButtonPress-2> <ButtonRelease-2> <B2-Motion>
               <Shift-ButtonPress-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
               <Alt-ButtonPress-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>} {
    bind $wp $seq {break}
  }
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
  $mb.graph add checkbutton -label {Shared X Axis} \
    -variable ::wviewer::sharedx($token) \
    -command [list wviewer::sharedx_toggle $token]
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
