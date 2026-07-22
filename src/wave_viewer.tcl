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
#     navigation always; the waves_callback key set only over a graph;
#     Ctrl-W = close; everything else silently swallowed — readonly alone
#     would pop the readonly_block MODAL on every editing key). Button-3 is
#     forwarded only over a graph (kills the schematic context menu, keeps
#     the C engine's graph pan/zoom), double-clicks are swallowed entirely
#     (D9: dbl-click would open graph_edit_properties whose writeback is
#     readonly-rejected; Axes editing is item 12). Per-widget binds provably
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
# rect prop string, add_graph template order), graph_geometry (stacked
# slots), next_color (D10 palette cycle), validate_rpn (D4 — the C RPN
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
# Pure Tcl, procs only at source time (safe under --nogui); ciw_echo only
# under has_x. TIP-278: `variable` declarations, absolute names.

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
  # per-dialog transient state (D13), cleaned on OK/cancel/forget
  variable axl;     array set axl {}
  variable delmap;  array set delmap {}
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
  variable axl; variable delmap
  if {[dict exists $windows $token]} {
    dict unset graphbb [dict get $windows $token win_path]
    dict unset windows $token
  }
  dict unset layouts $token
  catch {unset cva($token)}
  catch {unset cvb($token)}
  catch {unset cvr($token)}
  catch {unset sharedx($token)}
  array unset axl ${token},*
  catch {unset delmap($token)}
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
  wviewer::retitle $token
  bind $top <FocusIn> "+[list wviewer::retitle $token]"
  # WM-close (or any external destroy) must also clean the registry; every
  # descendant's <Destroy> carries the toplevel bindtag, hence the %W guard
  bind $top <Destroy> "+if {{%W} eq {$top}} {[list wviewer::forget $token]}"
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
# height) is DEFERRED — every graph gets the fixed graph_geometry slot.
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

# PURE (headless-checkable): canvas slot of graph index `i` — stacked
# vertically, 800x400 with a 50 gap (xschem y grows downward).
proc wviewer::graph_geometry {i} {
  set y [expr {$i * 450}]
  return [list 0 $y 800 [expr {$y + 400}]]
}

# PURE (D10): next auto-cycled trace color for model graph `G` — the first
# palette entry unused by its traces, else index by trace count mod length.
proc wviewer::next_color {G} {
  variable palette
  set used {}
  foreach tr [wviewer::dget $G traces {}] {
    lappend used [wviewer::dget $tr color {}]
  }
  foreach c $palette {
    if {[lsearch -exact $used $c] < 0} { return $c }
  }
  return [lindex $palette [expr {[llength $used] % [llength $palette]}]]
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
proc wviewer::graph_props {G} {
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
  return "flags=graph\ny1=$y1\ny2=$y2\nypos1=0\nypos2=2\ndivy=5\nsubdivy=1\nunity=1\nx1=$x1\nx2=$x2\ndivx=5\nsubdivx=1\nxlabmag=1.0\nylabmag=1.0\nlegendmag=1.0\nnode=\"$node\"\ncolor=\"$color\"\ndataset=-1\nunitx=1\nlogx=$logx\nlogy=$logy\n"
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
  wviewer::with_edit $token {
    xschem clear_drawing
    set gi_ 0
    foreach G_ $gs {
      lassign [wviewer::graph_geometry $gi_] rx1_ ry1_ rx2_ ry2_
      wviewer::place_graph_rect $rx1_ $ry1_ $rx2_ $ry2_ [wviewer::graph_props $G_]
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
  set bbs {}
  for {set i 0} {$i < [llength $gs]} {incr i} {
    lappend bbs [wviewer::graph_geometry $i]
  }
  dict set graphbb $wp $bbs
  xschem new_schematic switch $wp
  xschem zoom_full
  xschem redraw
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

# Append a trace to model graph `gi` of `token` (the Add Trace… core; also
# the scripting/test seam). `rpn` = a raw variable reference (single token)
# or a whitespace-separated RPN expression (D5: materialized as a raw
# vector named `name`/auto expr<N> via `xschem raw add`, so it then plots
# like any var). Returns {} on success or a user-displayable error message
# (never throws): D4 pre-validation, invalid names, missing raw data.
proc wviewer::add_trace {token gi rpn {name {}}} {
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
  lappend trs [dict create expr $rpn name $name vec $vec \
                           color [wviewer::next_color $G]]
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
# generation stays one-directional). Then canvas zoom_full + redraw.
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
  wviewer::in_ctx $token {xschem zoom_full; xschem redraw}
  wviewer::readout_refresh $token
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
#   always forwarded: f (fit / graph fullx), Z (zoom in), Ctrl-z (zoom out),
#     arrows (scroll / graph pan), Escape (abort+redraw — NEVER closes, D10);
#   over a graph only: a b s m t A B (+ctrl) — the waves_callback key set;
#   Ctrl-W: close the viewer (handled Tcl-side, swallowed);
#   everything else: swallowed silently (readonly backstops any miss).
proc wviewer::key_filter {W T x y N K s} {
  variable graphkeys
  if {($s & 4) && ($N == 119 || $N == 87)} {          ;# Ctrl-W / Ctrl-Shift-W
    if {$T == 2} { wviewer::close [wviewer::token_for_canvas $W] }
    return
  }
  set fwd 0
  if {$K eq {Escape}} {
    catch {destroy .ctxmenu}                          ;# mirror the editor bind
    set fwd 1
  } elseif {$N == 102 || $N == 90 || ($N == 122 && ($s & 4)) ||
            ($N >= 65361 && $N <= 65364)} {
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

# Button-3 filter: forwarded only over a graph (the C engine's graph
# pan/zoom); elsewhere swallowed, which kills the schematic context menu.
proc wviewer::btn3_filter {W T x y b s} {
  if {![wviewer::over_graph $W]} { return }
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
  bind $wp <Double-Button-1> {break}                  ;# D9: no graph props dlg
  bind $wp <Double-Button-2> {break}
  bind $wp <Double-Button-3> {break}
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
  foreach {label sub} {File file View view Graph graph Cursors cursors} {
    $mb add cascade -label $label -menu $mb.$sub
    menu $mb.$sub -tearoff 0 -takefocus 0 \
      -font AseLabelFont -background $panel -activebackground $header
  }
  $mb.file add command -label Close -accelerator Ctrl+W \
    -command [list wviewer::close $token]
  # View > Fit = graph-data autozoom + model read-back (D6); the rest are
  # plain canvas ops
  $mb.view add command -label Fit \
    -command [list wviewer::fit $token]
  $mb.view add command -label {Zoom In} \
    -command [list wviewer::in_ctx $token {xschem zoom_in}]
  $mb.view add command -label {Zoom Out} \
    -command [list wviewer::in_ctx $token {xschem zoom_out}]
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
  $top configure -menu $mb
}
