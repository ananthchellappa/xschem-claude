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
#     binding filter on THIS window's .drw only: the generic <KeyPress>/
#     <KeyRelease> binds are replaced by wviewer::key_filter (allowlist:
#     navigation always; the waves_callback key set only over a graph;
#     Ctrl-W = close; everything else silently swallowed — readonly alone
#     would pop the readonly_block MODAL on every editing key). Button-3 is
#     forwarded only over a graph (kills the schematic context menu, keeps
#     the C engine's graph pan/zoom), double-clicks are swallowed entirely
#     (D9: dbl-click would open graph_edit_properties whose writeback is
#     readonly-rejected; Axes editing is item 12). Per-widget binds provably
#     cannot affect other windows.
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
# Graph display seam (item 12 reshapes it): wviewer::display_raw places one
# graph rect (add_graph template with node/color filled) + `xschem raw read`
# + redraw. Honest assertability: raw points/vars/sim_type, layer-2 rect
# count/props, redraw rc, modified-still-0 — actual pixel rendering is
# eyeball-only.
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
proc wviewer::forget {token} {
  variable windows
  variable graphbb
  if {[dict exists $windows $token]} {
    dict unset graphbb [dict get $windows $token win_path]
    dict unset windows $token
  }
  return {}
}

# Raise-or-open the ONE viewer window of ASE session `token`. Returns 1 when
# the viewer is up (raised or freshly built), 0 on an unknown token (ciw_echo
# under has_x, never a throw — ase::open_state style) and 0 headless (the
# window shell is GUI-only; the session bookkeeping stays untouched).
proc wviewer::open {token} {
  variable windows
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

# Run `script` (caller's scope) against the viewer buffer with editing
# temporarily allowed. Contract (D1): switch to the viewer ctx, readonly 0,
# run, `set_modify 0` BEFORE readonly 1 (so modified can never stick), then
# re-assert the title (the readonly toggles clobber it, probe 2). The whole
# cycle is bracketed with `set autosave_backup 0` — write_backup DOES back up
# untitled buffers (issue 0060), and a with_edit mutation would drop
# untitled-N~.sch into the cwd. The script must not call `update`, so no
# foreign edit can interleave with the bracket. Errors from the script
# propagate AFTER the readonly/title/autosave restore.
proc wviewer::with_edit {token script} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  xschem new_schematic switch [dict get $windows $token win_path]
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

# --- graph display (D8 — the item-12 seam, kept minimal) ---------------------

# Place one graph rect on the viewer canvas (runs inside with_edit). Props =
# the add_graph template (scheduler.c) with node/color filled.
proc wviewer::place_graph_rect {props} {
  set save [xschem get rectcolor]
  xschem set rectcolor 2
  xschem rect 0 0 800 400 -1 $props 1
  xschem set rectcolor $save
}

# Display `rawfile` (sim type `sim_type`) in the viewer of `token`: create a
# graph rect bound to `node`, load the raw file, redraw. `rawfile` {} (or
# missing) creates the graph rect only. Returns 1, or 0 for an unknown token.
proc wviewer::display_raw {token rawfile sim_type node {color 4}} {
  variable windows
  variable graphbb
  if {![dict exists $windows $token]} { return 0 }
  set wp [dict get $windows $token win_path]
  set props "flags=graph\ny1=0\ny2=2\nypos1=0\nypos2=2\ndivy=5\nsubdivy=1\nunity=1\nx1=0\nx2=10e-6\ndivx=5\nsubdivx=1\nxlabmag=1.0\nylabmag=1.0\nlegendmag=1.0\nnode=\"$node\"\ncolor=$color\ndataset=-1\nunitx=1\nlogx=0\nlogy=0\n"
  wviewer::with_edit $token [list wviewer::place_graph_rect $props]
  dict lappend graphbb $wp [list 0 0 800 400]
  if {$rawfile ne {} && [file isfile $rawfile]} {
    xschem new_schematic switch $wp
    xschem raw read $rawfile $sim_type
  }
  xschem redraw
  return 1
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
  if {$fwd} { xschem callback $W $T $x $y $N 0 0 $s }
}

# Button-3 filter: forwarded only over a graph (the C engine's graph
# pan/zoom); elsewhere swallowed, which kills the schematic context menu.
proc wviewer::btn3_filter {W T x y b s} {
  if {![wviewer::over_graph $W]} { return }
  if {$T == 4} { catch {focus $W} }                   ;# ButtonPress focuses
  xschem callback $W $T $x $y 0 $b 0 $s
}

# Replace/override the editor bindings on the viewer canvas `wp` (per-widget:
# other windows keep their full binding set by construction).
proc wviewer::strip_bindings {wp} {
  bind $wp <KeyPress>   {wviewer::key_filter %W %T %x %y %N %K %s}
  bind $wp <KeyRelease> {wviewer::key_filter %W %T %x %y %N %K %s}
  # more-specific editor key binds that would pre-empt the generic filter
  bind $wp <Control-Shift-Key-P> {break}              ;# command palette
  if {[info exists ::hi_descend_key] && $::hi_descend_key ne {}} {
    bind $wp <Key-$::hi_descend_key> {break}          ;# hi_descend dialog
  }
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
  $mb.view add command -label Fit \
    -command [list wviewer::in_ctx $token {xschem zoom_full}]
  $mb.view add command -label {Zoom In} \
    -command [list wviewer::in_ctx $token {xschem zoom_in}]
  $mb.view add command -label {Zoom Out} \
    -command [list wviewer::in_ctx $token {xschem zoom_out}]
  $mb.view add command -label Redraw \
    -command [list wviewer::in_ctx $token {xschem redraw}]
  # TODO(item12): graph/trace editing + cursors land with the viewer core
  foreach l [list {Add Graph} {Add Trace...} Delete Axes...] {
    $mb.graph add command -label $l -state disabled
  }
  foreach l [list {Cursor A} {Cursor B} Readout] {
    $mb.cursors add command -label $l -state disabled
  }
  $top configure -menu $mb
}
