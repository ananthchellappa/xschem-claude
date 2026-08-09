# library_manager.tcl — a Cadence-style Library Manager (library-manager Phase 7).
#
# Layout follows the Cadence Library Manager: three always-visible columns,
# left to right, in a resizable paned window:
#
#     +-----------+-----------+-----------+
#     | Library   | Cell      | View      |
#     |  devices  |  res      |  schematic|
#     |  examples |  nmos4    |  symbol   |
#     |  logic    |  ...      |           |
#     +-----------+-----------+-----------+
#
# Selecting a library fills the Cell column; selecting a cell fills the View
# column. Double-click a view (or use the buttons) to open the schematic or
# place the symbol. (A Category column, as in Cadence, can slot between Library
# and Cell once xschem grows a category model; it is intentionally omitted now.)
#
# Built entirely on the read-only query commands:
#   xschem libraries / lib_cells <lib> / cell_views <lib> <cell>
# and the resolver `xschem cellview_path <lib/cell> <view>` (flat- and
# lib/cell/view-aware). Open with:  library_manager   (or Tools -> Library Manager)

namespace eval libmgr {
  variable sel_lib  "" ;# currently selected library name
  variable sel_cell "" ;# currently selected cell name
  variable suppress_select 0 ;# 1 while refresh_after drives the panes programmatically:
                             ;# the bound <<TreeviewSelect>> handlers are no-op'd so the
                             ;# deferred select events don't re-clear the Cell/View panes
                             ;# we just populated (see refresh_after / locate).
  variable suppress_after {} ;# pending `after idle` id that re-enables the handlers;
                             ;# cancelled+rescheduled per refresh_after so two cascades
                             ;# in one event-loop turn share a single reset that fires
                             ;# only after BOTH have populated (issue 0024).
  variable new_window 1 ;# open schematics in a new window/tab (vs the current one)
  variable hist_counter 0 ;# unique-id source for History dialog windows
  variable hist_msg       ;# array: history-window path -> dict(hash -> message)
  array set hist_msg {}
}

# Bring the (existing) Library Manager window to the front AND give it the
# keyboard focus. Plain `focus` cannot move focus across toplevels, so when
# another window (e.g. the CIW) is the active one it would be ignored -- we use
# `focus -force`. It is re-asserted at idle so this also works for a window that
# was just created and is not yet mapped. See doc/claude/specs/library_manager_launch.md.
proc libmgr::raise_to_front {} {
  set w .libmgr
  if {![winfo exists $w]} return
  # Bring it to the front via the shared helper (raises without the North-West creep
  # that the old re-map caused on every CTRL-ALT-S, issue 0054); then focus the list.
  raise_activate_toplevel $w
  catch {focus -force $w.pw.lib.lb}
  after idle [list libmgr::refocus $w]
}
proc libmgr::refocus {w} {
  if {[winfo exists $w]} { catch {focus -force $w.pw.lib.lb} }
}

# The optional argument is a list: a single element is a library name; a
# {lib cell} or {lib cell view} list pre-selects and scrolls to that entry
# (e.g. `xschem library_manager [xschem get_inst_lcv]`). With no arg this is the
# plain open/raise.
proc libmgr::open {{lcv {}}} {
  set w .libmgr
  if {[winfo exists $w]} {
    # single window: bring the existing one forward and focus it rather than
    # building a second one. See doc/claude/specs/library_manager_launch.md.
    libmgr::raise_to_front
    libmgr::refresh
    libmgr::locate $lcv
    return
  }
  toplevel $w
  wm title $w "Library Manager"
  wm geometry $w 760x460

  ## Window-activation logging (doc/claude/specs/window_numbering.md): the Library
  ## Manager is window 2. Fire on FocusIn to the toplevel or any descendant; the '+'
  ## preserves any other binding and notify_window_active dedupes the repeats.
  bind $w <FocusIn> {+notify_window_active 2 {Library Manager}}

  ttk::panedwindow $w.pw -orient horizontal
  # NOTE: $w.pw is packed LAST (after the bottom status/button bars below) — the
  # treeview's -height 20 makes the pane request more than the 460px window, so if
  # it were packed first with -expand it would claim the whole cavity and clip the
  # Open/Place/Refresh/Close bar off the bottom (fixed bottom bars must be packed
  # before the expanding central widget).

  # a bold font for git-tracked rows (doc/claude/specs/library_git.md §4.3). Derived from the
  # treeview's default font so it matches; created once.
  if {[lsearch -exact [font names] LibMgrBold] < 0} {
    catch {font create LibMgrBold {*}[font actual TkDefaultFont] -weight bold}
  }
  # one column = header label + treeview + scrollbar, in a frame added to the
  # pane. ttk::treeview (not listbox) so each row can carry a per-row font: a
  # revision-controlled library/cell/view renders bold. The treeview ROW ID is
  # the item name, so [$lb children {}] is the ordered name list and selection /
  # lookup are by name.
  foreach {col title} {lib Library cell Cell view View} {
    set f [ttk::frame $w.pw.$col]
    ttk::label $f.h -text $title -anchor w -padding {4 2}
    ttk::treeview $f.lb -show tree -selectmode browse -height 20 \
            -yscrollcommand "$f.sb set"
    $f.lb column #0 -width 150
    $f.lb tag configure tracked -font LibMgrBold
    ttk::scrollbar $f.sb -orient vertical -command "$f.lb yview"
    grid $f.h  -row 0 -column 0 -columnspan 2 -sticky we
    grid $f.lb -row 1 -column 0 -sticky nsew
    grid $f.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $f 1 -weight 1
    grid columnconfigure $f 0 -weight 1
    $w.pw add $f -weight 1
  }

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} -text "select a library"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.open  -text "Open" -command libmgr::open_view
  ttk::button $w.b.place -text "Place symbol"   -command libmgr::place_symbol
  ttk::checkbutton $w.b.neww -text "New window" -variable libmgr::new_window
  ttk::button $w.b.ref   -text "Refresh"        -command libmgr::refresh
  ttk::button $w.b.close -text "Close"          -command "destroy $w"
  pack $w.b.open $w.b.place $w.b.neww $w.b.ref -side left -padx 4 -pady 4
  pack $w.b.close -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  # expanding 3-pane area fills whatever is left ABOVE the status + button bars
  pack $w.pw -side top -fill both -expand 1

  # guard against the deferred-select clobber: a programmatic `selection set` (in
  # refresh_after/locate) queues a <<TreeviewSelect>> that would re-run on_lib and
  # wipe the Cell/View panes after we filled them. Skip the handler while suppressed.
  bind $w.pw.lib.lb  <<TreeviewSelect>> {if {!$libmgr::suppress_select} libmgr::on_lib}
  bind $w.pw.cell.lb <<TreeviewSelect>> {if {!$libmgr::suppress_select} libmgr::on_cell}
  bind $w.pw.view.lb <<TreeviewSelect>> {if {!$libmgr::suppress_select} libmgr::on_view}
  bind $w.pw.cell.lb <Double-1>         libmgr::open_view
  bind $w.pw.view.lb <Double-1>         libmgr::open_view

  libmgr::build_menus $w
  libmgr::build_menubar $w
  bind $w.pw.lib.lb  <Button-3> {libmgr::ctx_post lib  %x %y %X %Y}
  bind $w.pw.cell.lb <Button-3> {libmgr::ctx_post cell %x %y %X %Y}
  bind $w.pw.view.lb <Button-3> {libmgr::ctx_post view %x %y %X %Y}

  libmgr::populate_libs
  # a freshly created window should also come up focused, even if another
  # toplevel (the CIW, the main window) was active when it was launched.
  libmgr::raise_to_front
  libmgr::locate $lcv
}

# Pre-select and scroll to a {lib cell view} entry across the three panes (a
# single list argument, like libmgr::open: cell/view optional, e.g.
# `libmgr::locate [libmgr::selection]`). Reuses refresh_after for the actual
# selection wiring, then scrolls each chosen row into view; reports the first
# missing piece on the status bar. A no-op for an empty list or no window.
proc libmgr::locate {lcv} {
  lassign $lcv lib cell view
  if {![winfo exists .libmgr] || $lib eq ""} return
  # refresh_after selects lib -> cell -> view across the three panes and scrolls
  # each into view (treeview `see`). It is the single source of truth for the
  # cascade; the old per-pane listbox lookups here errored on the ttk::treeview.
  libmgr::refresh_after $lib $cell $view
}

# Per-column right-click menus, built once and re-targeted on each click.
proc libmgr::build_menus {w} {
  catch {destroy $w.mlib $w.mcell $w.mview}

  menu $w.mlib -tearoff 0
  $w.mlib add command -label "New cell…"    -command libmgr::ctx_new_cell
  $w.mlib add command -label "New library…" -command libmgr::ctx_new_library
  $w.mlib add separator
  $w.mlib add command -label "Show Checkouts" -command libmgr::ctx_show_checkouts
  $w.mlib add command -label "Check in…"      -command libmgr::ctx_checkin_lib
  $w.mlib add command -label "History"        -command libmgr::ctx_history_lib
  $w.mlib add separator
  $w.mlib add command -label "Remove from list" -command libmgr::ctx_unregister_lib
  $w.mlib add separator
  $w.mlib add command -label "Refresh" -command libmgr::refresh

  menu $w.mcell -tearoff 0
  $w.mcell add command -label "Open"             -command libmgr::open_view
  $w.mcell add command -label "Open (read-only)" -command libmgr::open_view_ro
  $w.mcell add separator
  $w.mcell add command -label "Check out"        -command libmgr::ctx_checkout_cell
  $w.mcell add command -label "Check in…"        -command libmgr::ctx_checkin_cell
  $w.mcell add command -label "Cancel checkout"  -command libmgr::ctx_cancel_checkout_cell
  $w.mcell add command -label "History"          -command libmgr::ctx_history_cell
  $w.mcell add separator
  $w.mcell add command -label "Copy…"   -command libmgr::ctx_copy_cell
  $w.mcell add command -label "Rename…" -command libmgr::ctx_rename_cell
  $w.mcell add command -label "Delete"       -command libmgr::ctx_delete_cell
  $w.mcell add separator
  $w.mcell add command -label "New cell…" -command libmgr::ctx_new_cell
  $w.mcell add command -label "New view…" -command libmgr::ctx_new_view

  menu $w.mview -tearoff 0
  $w.mview add command -label "Open"             -command libmgr::open_view
  $w.mview add command -label "Open (read-only)" -command libmgr::open_view_ro
  $w.mview add separator
  $w.mview add command -label "Check out"        -command libmgr::ctx_checkout_view
  $w.mview add command -label "Check in…"        -command libmgr::ctx_checkin_view
  $w.mview add command -label "Cancel checkout"  -command libmgr::ctx_cancel_checkout_view
  $w.mview add command -label "History"          -command libmgr::ctx_history_view
  $w.mview add separator
  $w.mview add command -label "Copy…"   -command libmgr::ctx_copy_view
  $w.mview add command -label "Rename…" -command libmgr::ctx_rename_view
  $w.mview add command -label "New view…" -command libmgr::ctx_new_view
  $w.mview add separator
  $w.mview add command -label "Delete view" -command libmgr::ctx_delete_view
}

# The window's real menubar (the panes also have right-click popups). The
# Maintain cascade hosts the git revision-control reports (doc/claude/specs/library_git.md).
proc libmgr::build_menubar {w} {
  set mb $w.menubar
  catch {destroy $mb}
  menu $mb -tearoff 0
  $w configure -menu $mb
  menu $mb.maintain -tearoff 0
  $mb add cascade -label Maintain -menu $mb.maintain
  $mb.maintain add command -label "Show Status…" -command libmgr::show_status
  $mb.maintain add command -label "History…"     -command libmgr::show_history
}

# Modal multi-select library picker shared by the Maintain reports. Ctrl/Shift-
# click extends the selection (selectmode extended). Returns the chosen library
# names, or {} on Cancel / empty selection.
proc libmgr::maintain_picker {title} {
  variable dlg_done
  set d .libmgr.mp
  catch {destroy $d}
  toplevel $d
  wm title $d $title
  wm transient $d .libmgr
  ttk::label $d.l -text "Select one or more libraries (Ctrl/Shift-click):" -anchor w
  listbox $d.lb -selectmode extended -exportselection 0 \
          -yscrollcommand "$d.sb set" -width 32 -height 14
  ttk::scrollbar $d.sb -orient vertical -command "$d.lb yview"
  foreach name [libmgr::lib_names] { $d.lb insert end $name }
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l  -row 0 -column 0 -columnspan 2 -sticky we  -padx 6 -pady {6 2}
  grid $d.lb -row 1 -column 0 -sticky nsew -padx {6 0} -pady 2
  grid $d.sb -row 1 -column 1 -sticky ns   -padx {0 6} -pady 2
  grid $d.b  -row 2 -column 0 -columnspan 2 -pady 6
  grid rowconfigure $d 1 -weight 1
  grid columnconfigure $d 0 -weight 1
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.lb
  vwait libmgr::dlg_done
  set res {}
  if {$dlg_done == 1} { foreach i [$d.lb curselection] { lappend res [$d.lb get $i] } }
  catch {destroy $d}
  return $res
}

# Maintain → Show Status: pick libraries, render their untracked / pending
# cellviews in the read-only viewdata text window.
proc libmgr::show_status {} {
  set libs [libmgr::maintain_picker "Show Status — pick libraries"]
  if {![llength $libs]} return
  viewdata [lib_git_status_report $libs] ro
}

# Maintain → History: pick libraries, render their git log in viewdata.
proc libmgr::show_history {} {
  set libs [libmgr::maintain_picker "History — pick libraries"]
  if {![llength $libs]} return
  viewdata [lib_git_history_report $libs] ro
}

# Right-click at widget coords ($x,$y) in column $col: select the row under the
# pointer, sync the panes, then post that column's menu. `identify item x y`
# needs BOTH coordinates (a single arg misparses as the legacy `identify x y`).
proc libmgr::ctx_post {col x y rootx rooty} {
  set lb .libmgr.pw.$col.lb
  set id ""
  catch {$lb identify item $x $y} id
  if {$id ne ""} {
    $lb selection set $id; $lb focus $id
    switch -- $col { lib {libmgr::on_lib} cell {libmgr::on_cell} view {libmgr::on_view} }
  }
  catch {tk_popup .libmgr.m$col $rootx $rooty}
}

# helper: the selected item NAME in a pane treeview, or "" if none. The row id is
# the item name, so the selection is already the name.
proc libmgr::cursel {lb} {
  set s [$lb selection]
  if {$s eq {}} { return "" }
  return [lindex $s 0]
}

# Fill pane $col's treeview with $names (clearing first); rows whose name is a key
# of the $tracked dict (used as a set) get the bold `tracked` tag. Row id == name.
proc libmgr::pane_fill {col names {tracked {}}} {
  set t .libmgr.pw.$col.lb
  $t delete [$t children {}]
  foreach n $names {
    $t insert {} end -id $n -text $n
    if {[dict exists $tracked $n]} { $t item $n -tags tracked }
  }
}
proc libmgr::pane_clear {col} {
  set t .libmgr.pw.$col.lb
  $t delete [$t children {}]
}

# --- git-tracked sets driving the bold tag (doc/claude/specs/library_git.md §4.3) --------
# Each returns a dict used as a set; empty (nothing bold) when the library is not
# under git or git is absent (lib_git_tracked_set degrades to {}). A library is
# bold if it holds any tracked datafile; a cell if any of its views are tracked;
# a view if its own datafile is tracked.
proc libmgr::tracked_libs {} {
  set out [dict create]
  foreach pair [xschem libraries] {
    if {[dict size [lib_git_tracked_set [lindex $pair 1]]] > 0} { dict set out [lindex $pair 0] 1 }
  }
  return $out
}
proc libmgr::tracked_cells {lib} {
  set out [dict create]
  set path [library_resolve $lib]
  if {$path eq ""} { return $out }
  dict for {cv v} [lib_git_tracked_set $path] { dict set out [lindex [split $cv /] 0] 1 }
  return $out
}
proc libmgr::tracked_views {lib cell} {
  set out [dict create]
  set path [library_resolve $lib]
  if {$path eq ""} { return $out }
  dict for {cv v} [lib_git_tracked_set $path] {
    lassign [split $cv /] c view
    if {$c eq $cell} { dict set out $view 1 }
  }
  return $out
}

proc libmgr::populate_libs {} {
  variable sel_lib; variable sel_cell
  set names {}
  foreach pair [xschem libraries] { lappend names [lindex $pair 0] }
  libmgr::pane_fill lib $names [libmgr::tracked_libs]
  libmgr::pane_clear cell
  libmgr::pane_clear view
  set sel_lib ""; set sel_cell ""
}

proc libmgr::refresh {} {
  if {[winfo exists .libmgr]} { libmgr::populate_libs }
}

# library selected -> fill the Cell column, clear the View column
proc libmgr::on_lib {args} {
  variable sel_lib; variable sel_cell
  set sel_lib [libmgr::cursel .libmgr.pw.lib.lb]
  set sel_cell ""
  libmgr::pane_clear cell
  libmgr::pane_clear view
  if {$sel_lib ne ""} {
    libmgr::pane_fill cell [xschem lib_cells $sel_lib] [libmgr::tracked_cells $sel_lib]
  }
  .libmgr.status configure -text "library: $sel_lib"
}

# cell selected -> fill the View column
proc libmgr::on_cell {args} {
  variable sel_lib; variable sel_cell
  set sel_cell [libmgr::cursel .libmgr.pw.cell.lb]
  libmgr::pane_clear view
  if {$sel_lib ne "" && $sel_cell ne ""} {
    libmgr::pane_fill view [xschem cell_views $sel_lib $sel_cell] [libmgr::tracked_views $sel_lib $sel_cell]
  }
  .libmgr.status configure -text "$sel_lib / $sel_cell"
}

proc libmgr::on_view {args} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  .libmgr.status configure -text "$sel_lib / $sel_cell / $v"
}

# the {lib cell} currently selected, or {} if incomplete
proc libmgr::current_cell {} {
  variable sel_lib; variable sel_cell
  if {$sel_lib eq "" || $sel_cell eq ""} { return {} }
  return [list $sel_lib $sel_cell]
}

# the {lib cell view} to open: the selected view, or (if only a cell is chosen)
# its schematic if present else its first view. {} if nothing usable.
proc libmgr::current_view {} {
  variable sel_lib; variable sel_cell
  if {$sel_lib eq "" || $sel_cell eq ""} { return {} }
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$v eq ""} {
    set views [xschem cell_views $sel_lib $sel_cell]
    if {[lsearch $views schematic] >= 0} { set v schematic } \
    elseif {[llength $views] > 0} { set v [lindex $views 0] } \
    else { return {} }
  }
  return [list $sel_lib $sel_cell $v]
}

# Report exactly what is currently selected in the panes, as a list graded by
# how deep the selection goes (the inverse of libmgr::locate /
# `xschem library_manager <lcv>`):
#   nothing selected      -> {}                        (empty)
#   only a library        -> {libName}                 (1-element list)
#   library + cell        -> {libName cellName}
#   library + cell + view -> {libName cellName viewName}
# Unlike current_view, this does NOT infer a default view -- it reports the view
# only when one is actually selected. Returns {} if the window is not open.
proc libmgr::selection {} {
  variable sel_lib; variable sel_cell
  if {![winfo exists .libmgr] || $sel_lib eq ""} { return {} }
  set out [list $sel_lib]
  if {$sel_cell eq ""} { return $out }
  lappend out $sel_cell
  set view [libmgr::cursel .libmgr.pw.view.lb]
  if {$view ne ""} { lappend out $view }
  return $out
}

# View-type dispatch table (the item-02/03 ASE dispatch seam,
# doc/claude/specs/ase_l.md): which handler opens a view. When the resolved
# datafile $path is given its EXTENSION is authoritative (codebase doctrine: a
# view's editor type comes from its <cell>.<ext> datafile, not its label —
# library_defs.tcl cellview_resolve), which makes both mismatch directions
# safe: a view named 'mystate' holding a .state never reaches `xschem load`,
# and a view named 'ngspice_state1' holding a .sch still opens in the editor.
# Without a path the view NAME decides (a *_state* name -> ASE, `verilog` /
# `veriloga` -> text). Returns a handler proc (called as
# `<handler> $lib $cell $view`) or the token `editor` (status-quo load arms).
#
# `editor` means `xschem load`, and `xschem load` on a NON-SCHEMATIC text file
# does not fail: it skips every line and leaves an empty schematic whose
# schname is that file, marked unmodified — so the next save writes an empty
# .sch over the source. That is why .v/.va must divert here and not merely
# "look nicer in the tree". Measured against
# xschem_libraries_oa/ngspice_verilog_cosim_ase/counter/verilog/counter.v; see
# the §B preamble of doc/claude/specs/mixed_signal_signal_browser.md.
proc libmgr::view_handler {view {path {}}} {
  # extension wins when we have a datafile, view name is the fallback — the one
  # table in library_defs.tcl decides both.
  set type [expr {$path ne {} ? [view_type_of_ext [file extension $path]] : $view}]
  switch -- [view_type_opener $type] {
    ase     { return ase::open_state }
    text    { return libmgr::open_text_view }
    default { return editor }
  }
}

# Handler for source-code views (verilog, veriloga): hand the datafile to the
# configured text editor. edit_file already falls back to the internal text
# window when $editor is not executable (editor-missing-fallback), so this needs
# no display check of its own.
#
# Logs NO action line, like the ASE arm: `edit_file` spawns an external process,
# which is not a replayable xschem operation — a replay must not fork gvim.
# The $ro flag is accepted for handler-signature parity with ase::open_state and
# reported honestly: an external editor is not ours to make read-only.
proc libmgr::open_text_view {lib cell view {ro 0}} {
  set path [xschem cellview_path "$lib/$cell" $view]
  if {$path eq {}} { libmgr::status "no $view view for $lib/$cell"; return 0 }
  edit_file $path
  set note [expr {$ro ? " (an external editor cannot be forced read-only)" : ""}]
  libmgr::status "opened $lib/$cell/$view in the text editor$note"
  return 1
}

# open the selected view in its editor (schematic OR symbol), in a new window or
# the current one per the "New window" checkbox. Non-editor views (ASE
# simulation states) divert to their view_handler instead.
proc libmgr::open_view {args} {
  variable new_window
  set lcv [libmgr::current_view]
  if {$lcv eq {}} { return 0 }
  lassign $lcv lib cell view
  set f [xschem cellview_path "$lib/$cell" $view]
  if {$f eq {}} { .libmgr.status configure -text "no $view view for $lib/$cell"; return 0 }
  # ASE dispatch: a non-editor view never reaches `xschem load`. Its arm logs
  # NO action line (read-only viewer — same allowlist doctrine as do_history*/
  # do_show_checkouts) and skips the deferred force_window_repaint below (no
  # editor window was touched).
  set handler [libmgr::view_handler $view $f]
  if {$handler ne {editor}} { return [$handler $lib $cell $view] }
  # action-log: record the replayable open, DEDUP-GATED (reset + -emitted, the
  # menu_action_logged pattern). The C side already logs some arms itself -- the
  # `load -gui` pristine-window arm records `xschem load {f}` at the scheduler's
  # -gui hook -- so an unconditional line here double-logged the open (and the
  # `-gui` copy would replay interactively). The gated fallback still covers the
  # arms C leaves silent (load_new_window -window; the routed new-window load).
  if {$new_window} {
    # -window forces a real top-level OS window (draggable to another monitor),
    # not just a tab, even when the tabbed interface is on
    # (doc/claude/specs/multi_window_detach.md).
    xschem log_action -reset
    xschem load_new_window -window $f
    if {![xschem log_action -emitted]} {
      xschem log_action "xschem load_new_window -window {$f}"
    }
  } else {
    # -gui: interactive open. Reuse THIS window only if it is a pristine empty
    # untitled scratch; if it already holds a cellview (or has objects), open a
    # new window instead of clobbering it (doc/claude/specs/load_window_routing.md).
    xschem log_action -reset
    xschem load -gui $f
    if {![xschem log_action -emitted]} {
      xschem log_action "xschem load -gui {$f}"
    }
  }
  # WSLg leaves the target window blank (and its renamed tab stale) when a load is
  # driven from this persistent dialog: the window never gets the focus/expose that
  # would flush the paint. Force a deferred repaint of it. No-op on a normal X server
  # / when the window already painted (issue 0052).
  after 120 [list force_window_repaint [xschem get current_win_path] 0]
  return 1
}

proc libmgr::place_symbol {} {
  set lc [libmgr::current_cell]
  if {$lc eq {}} return
  set ref "[lindex $lc 0]/[lindex $lc 1]"
  if {[xschem cellview_path $ref symbol] ne {}} { xschem place_symbol $ref } \
  else { .libmgr.status configure -text "no symbol view for $ref" }
}

# --- context-menu actions --------------------------------------------------
# Each ctx_* gathers input (confirm box / dialog) then delegates to a do_*
# worker that takes explicit args, calls the library_defs.tcl backend, refreshes
# the panes and reports via the status bar. The do_* layer is the testable seam
# (no modal dialogs), returning 1 on success and 0 on a caught backend error.
#
# ACTION LOG (issue 0064 / 0071 atom 7): every MUTATING do_* worker records its
# own call line on the success arm only — log_action of the [list]-built
# `libmgr::do_<op> <args>` call, just before `return 1` — so every ctx_* dialog
# Cancel (all divert
# BEFORE reaching do_*) and every caught backend error leave no line. These are
# Tcl-only mutations (no C core to self-log); the do_* seam is the single
# logging site. Do NOT log in the library_defs.tcl / library_git.tcl backends:
# they are shared sub-steps (lib_git_restore is cancel-checkout's internal
# step; library_copy_cell+library_delete_cell compose a cross-library rename)
# and logging there double-counts. [list] keeps brace/backslash/newline args
# (free-text commit messages) source-able; a multiline message spans log lines
# inside balanced braces — same accepted class as the TCP multi-line records.
# Replay caveats (faithful-to-the-op, accepted): do_checkin_lib re-sweeps
# whatever is pending under the library at REPLAY time; do_cancel_checkout
# discards replay-time uncommitted edits (it is destructive by contract);
# do_new_library logs the path the user gave — an empty {} re-resolves the
# default (beside library.defs) at replay. Read-only viewers (do_history*,
# do_show_checkouts) stay unlogged. test_selflog_grep_guard locks this twice:
# an S1 row pins the site count and the S1b closure scan enumerates every
# `proc libmgr::do_*` -- a NEW mutating worker that does not log its own name
# (or join the read-only allowlist there) fails the guard closed.
# Test: tests/headless/test_libmgr_mutation_log.tcl.

proc libmgr::status {msg} { catch {.libmgr.status configure -text $msg} }

proc libmgr::lib_names {} {
  set out {}
  foreach pair [xschem libraries] { lappend out [lindex $pair 0] }
  return $out
}

# Rebuild the Library pane, then restore the given lib (and cell/view) selection
# so the panes reflect a just-completed mutation. Selection is by name (the
# treeview row id), so a missing target simply leaves the deeper panes empty.
proc libmgr::refresh_after {{lib {}} {cell {}} {view {}}} {
  variable sel_lib; variable sel_cell; variable suppress_select; variable suppress_after
  # headless guard: in a --nogui / display-less session Tk is not loaded, so a
  # bare `winfo` here is an ERROR, not a false -- and it fires AFTER the do_*
  # backend has already mutated disk, so a logged libmgr::do_* line would
  # abort its own recording and abort a log replay mid-file (atom-7 review).
  if {[info commands winfo] eq {} || ![winfo exists .libmgr]} return
  # Drive the panes programmatically with the bound select-handlers suppressed, so
  # the deferred <<TreeviewSelect>> events queued by our `selection set` calls fire
  # as no-ops (they run before the after-idle reset below) instead of re-clearing
  # the Cell/View panes we are about to populate. Scheduled up front so early
  # returns still re-enable the handlers. Cancel any pending reset first so two
  # refresh_after calls in one event-loop turn collapse to a single reset that runs
  # only after the LAST cascade's deferred events drain (issue 0024).
  set suppress_select 1
  if {$suppress_after ne {}} { after cancel $suppress_after }
  set suppress_after [after idle {set libmgr::suppress_select 0; set libmgr::suppress_after {}}]
  libmgr::populate_libs
  if {$lib eq {}} return
  set ll .libmgr.pw.lib.lb
  if {![$ll exists $lib]} return
  $ll selection set $lib; $ll focus $lib; $ll see $lib
  libmgr::on_lib
  if {$cell eq {}} return
  set cl .libmgr.pw.cell.lb
  if {![$cl exists $cell]} return
  $cl selection set $cell; $cl focus $cell; $cl see $cell
  libmgr::on_cell
  if {$view eq {}} return
  set vl .libmgr.pw.view.lb
  if {![$vl exists $view]} return
  $vl selection set $view; $vl focus $view; $vl see $view
  libmgr::on_view
}

# Open (read-only): open the view, then force the opened window into read-only
# (file-protected) mode. A plain Open already falls back to read-only on its own
# when the file is not writable; this forces it even for writable files.
proc libmgr::open_view_ro {} {
  set lcv [libmgr::current_view]
  if {$lcv eq {}} return
  lassign $lcv lib cell view
  # Non-editor views (ASE simulation states, source-code views): dispatch
  # DIRECTLY, through the resolved handler, with the read-only flag (the
  # handlers' trailing arg — for ase::open_state, item 07 D7: it records the
  # session attr `readonly` that gates the ASE Save-As overwrite confirmation).
  # Routing through libmgr::open_view would drop the flag, and the `xschem set
  # readonly 1` below would wrongly mark the CURRENT schematic window read-only
  # instead. Like the plain-open non-editor arms this logs NO action line
  # (read-only viewer allowlist doctrine). Dispatch is via $handler and not a
  # hardcoded ase::open_state: with .v/.va views the non-editor set is no
  # longer ASE-only, and calling ase::open_state on a Verilog file would report
  # a bogus unloadable-state error.
  set handler [libmgr::view_handler $view [xschem cellview_path "$lib/$cell" $view]]
  if {$handler ne {editor}} {
    if {![$handler $lib $cell $view 1]} return
    libmgr::status "opened $lib/$cell/$view read-only"
    return
  }
  if {![libmgr::open_view]} return
  xschem set readonly 1
  xschem log_action "xschem set readonly 1"
  libmgr::status "opened $lib/$cell/$view read-only"
}

# --- delete ---
proc libmgr::ctx_delete_cell {} {
  set lc [libmgr::current_cell]
  if {$lc eq {}} return
  lassign $lc lib cell
  set ans [tk_messageBox -parent .libmgr -type yesno -icon warning -title "Delete cell" \
    -message "Delete cell '$lib/$cell'?\n\nIt is moved to the library trash (.xschem_trash) and can be restored."]
  if {$ans eq "yes"} { libmgr::do_delete_cell $lib $cell }
}
proc libmgr::do_delete_cell {lib cell} {
  if {[catch {library_delete_cell $lib $cell} e]} { libmgr::status "delete failed: $e"; return 0 }
  libmgr::refresh_after $lib
  libmgr::status "deleted $lib/$cell (recoverable in .xschem_trash)"
  xschem log_action [list libmgr::do_delete_cell $lib $cell]
  return 1
}

proc libmgr::ctx_delete_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  set ans [tk_messageBox -parent .libmgr -type yesno -icon warning -title "Delete view" \
    -message "Delete the '$v' view of '$sel_lib/$sel_cell'?\n\nIt is moved to the library trash and can be restored."]
  if {$ans eq "yes"} { libmgr::do_delete_view $sel_lib $sel_cell $v }
}
proc libmgr::do_delete_view {lib cell view} {
  if {[catch {library_delete_view $lib $cell $view} e]} { libmgr::status "delete failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell
  libmgr::status "deleted view $lib/$cell/$view (recoverable in .xschem_trash)"
  xschem log_action [list libmgr::do_delete_view $lib $cell $view]
  return 1
}

# --- git revision control (doc/claude/specs/library_git.md §4.2) ------------------------
# The do_* workers here are the dialog-free seam: explicit args, call the
# library_git.tcl backend, refresh the panes, report via the status bar, return
# 1 on success and 0 on a caught backend error (e.g. nothing to commit).

# "<lib>/<cell>" or "<lib>/<cell>/<view>" for status messages.
proc libmgr::cv_label {lib cell {view {}}} {
  set s "$lib/$cell"; if {$view ne {}} { append s "/$view" }; return $s
}
# The datafile path(s) for a target: one view -> its datafile; a whole cell ->
# every view's datafile. Resolved via the same path rules as Open.
proc libmgr::cellview_files {lib cell {view {}}} {
  set out {}
  if {$view ne {}} {
    set f [xschem cellview_path "$lib/$cell" $view]
    if {$f ne {}} { lappend out $f }
  } else {
    foreach v [xschem cell_views $lib $cell] {
      set f [xschem cellview_path "$lib/$cell" $v]
      if {$f ne {}} { lappend out $f }
    }
  }
  return $out
}
# {root pathspecs} for a target (all its files share one repo root). Throws if
# the target has no datafile or is not under git.
proc libmgr::git_target {lib cell {view {}}} {
  set files [libmgr::cellview_files $lib $cell $view]
  if {![llength $files]} { error "no datafile for [libmgr::cv_label $lib $cell $view]" }
  set ctx [lib_git_context [lindex $files 0]]
  if {$ctx eq {}} { error "[libmgr::cv_label $lib $cell] is not under git revision control" }
  lassign $ctx root x
  set ps {}
  foreach f $files { lappend ps [lib_git_relpath $root $f] }
  return [list $root $ps]
}

proc libmgr::do_checkout {lib cell {view {}}} {
  if {[catch {
    foreach f [libmgr::cellview_files $lib $cell $view] { lib_git_checkout $f }
  } e]} { libmgr::status "check out failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell $view
  libmgr::status "checked out [libmgr::cv_label $lib $cell $view]"
  xschem log_action [list libmgr::do_checkout $lib $cell $view]
  return 1
}

proc libmgr::do_cancel_checkout {lib cell {view {}}} {
  if {[catch {
    foreach f [libmgr::cellview_files $lib $cell $view] { lib_git_cancel_checkout $f }
  } e]} { libmgr::status "cancel checkout failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell $view
  libmgr::status "cancelled checkout of [libmgr::cv_label $lib $cell $view]"
  xschem log_action [list libmgr::do_cancel_checkout $lib $cell $view]
  return 1
}

proc libmgr::do_checkin {lib cell view message} {
  if {[catch {
    lassign [libmgr::git_target $lib $cell $view] root ps
    lib_git_commit $root $ps $message
  } e]} { libmgr::status "check in failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell $view
  libmgr::status "checked in [libmgr::cv_label $lib $cell $view]"
  xschem log_action [list libmgr::do_checkin $lib $cell $view $message]
  return 1
}

# Library-level check-in: commit everything pending under THIS library's pathspec
# only (never a sibling library or unrelated repo files — spec §2.1 / §7).
proc libmgr::do_checkin_lib {lib message} {
  if {[catch {
    set path [library_resolve $lib]
    if {$path eq {}} { error "no such library: $lib" }
    set ctx [lib_git_context $path]
    if {$ctx eq {}} { error "$lib is not under git revision control" }
    lassign $ctx root pathspec
    lib_git_commit $root [list $pathspec] $message
  } e]} { libmgr::status "check in failed: $e"; return 0 }
  libmgr::refresh_after $lib
  libmgr::status "checked in library $lib"
  xschem log_action [list libmgr::do_checkin_lib $lib $message]
  return 1
}

# A local-mode-labelled report of a library's checked-out cell/views (spec §3:
# under plain git this is YOUR uncommitted edits + checkouts, not cross-user
# locks; the label makes that explicit).
proc libmgr::checkouts_text {lib} {
  set path [library_resolve $lib]
  if {$path eq {}} { return "Library '$lib' not found.\n" }
  set lfs [expr {[lsearch -exact [lib_git_available] lfs] >= 0}]
  set mode [expr {$lfs ? "Git LFS locks" : "local edit-lock (your uncommitted edits + checkouts)"}]
  set out "Checkouts for library '$lib'  \[mode: $mode\]\n\n"
  if {[lib_git_root $path] eq {}} { append out "  (not under git revision control)\n"; return $out }
  set cks [lib_git_checkouts $path]
  if {![llength $cks]} { append out "  (nothing checked out)\n"; return $out }
  foreach cv $cks { append out "  $cv\n" }
  return $out
}
proc libmgr::do_show_checkouts {lib} {
  viewdata [libmgr::checkouts_text $lib] ro
  return 1
}

# --- History form (two panes: commit list above, message below) --------------
# Non-modal viewer. Upper ttk::treeview lists commits (date | short hash |
# subject), newest first; selecting one shows its full message in the lower
# read-only text pane. Returns the window path. Scoped to $pathspecs.
proc libmgr::history_dialog {title root pathspecs} {
  variable hist_counter
  variable hist_msg
  # prune state for any History windows the user already closed
  foreach k [array names hist_msg] { if {![winfo exists $k]} { unset hist_msg($k) } }
  incr hist_counter
  set w .lmhist$hist_counter
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  wm geometry $w 660x480

  ttk::panedwindow $w.pw -orient vertical
  ttk::frame $w.top
  ttk::treeview $w.top.tv -columns {date hash subject} -show headings \
      -selectmode browse -yscrollcommand "$w.top.sb set"
  $w.top.tv heading date    -text Date
  $w.top.tv heading hash    -text Commit
  $w.top.tv heading subject -text Subject
  $w.top.tv column date    -width 130 -stretch 0
  $w.top.tv column hash    -width 90  -stretch 0
  $w.top.tv column subject -width 400 -stretch 1
  ttk::scrollbar $w.top.sb -orient vertical -command "$w.top.tv yview"
  grid $w.top.tv -row 0 -column 0 -sticky nsew
  grid $w.top.sb -row 0 -column 1 -sticky ns
  grid rowconfigure $w.top 0 -weight 1
  grid columnconfigure $w.top 0 -weight 1

  ttk::frame $w.bot
  text $w.bot.txt -height 8 -wrap word -state disabled -yscrollcommand "$w.bot.sb set"
  ttk::scrollbar $w.bot.sb -orient vertical -command "$w.bot.txt yview"
  grid $w.bot.txt -row 0 -column 0 -sticky nsew
  grid $w.bot.sb  -row 0 -column 1 -sticky ns
  grid rowconfigure $w.bot 0 -weight 1
  grid columnconfigure $w.bot 0 -weight 1

  $w.pw add $w.top -weight 3
  $w.pw add $w.bot -weight 1
  ttk::frame $w.b
  ttk::button $w.b.close -text Close -command [list destroy $w]
  pack $w.b.close -side right -padx 4
  pack $w.b -side bottom -fill x -pady 2
  pack $w.pw -side top -fill both -expand 1

  set hist_msg($w) [dict create]
  foreach rec [lib_git_log_records $root $pathspecs] {
    set hash [dict get $rec hash]
    $w.top.tv insert {} end -id $hash -values [list \
      [dict get $rec date] [dict get $rec short] [dict get $rec subject]]
    set full "commit [dict get $rec short]    [dict get $rec date]    [dict get $rec author]\n\n[dict get $rec subject]"
    set body [dict get $rec body]
    if {$body ne {}} { append full "\n\n$body" }
    dict set hist_msg($w) $hash $full
  }
  bind $w.top.tv <<TreeviewSelect>> [list libmgr::history_show $w]
  bind $w <Escape> [list destroy $w]
  set first [lindex [$w.top.tv children {}] 0]
  if {$first ne {}} { $w.top.tv selection set $first; libmgr::history_show $w }
  return $w
}

# Refresh the lower message pane from the selected commit row.
proc libmgr::history_show {win} {
  variable hist_msg
  if {![winfo exists $win.top.tv]} return
  set sel [$win.top.tv selection]
  set msg ""
  if {$sel ne {} && [info exists hist_msg($win)] && [dict exists $hist_msg($win) [lindex $sel 0]]} {
    set msg [dict get $hist_msg($win) [lindex $sel 0]]
  }
  $win.bot.txt configure -state normal
  $win.bot.txt delete 1.0 end
  $win.bot.txt insert end $msg
  $win.bot.txt configure -state disabled
}

# do_history seam: resolve the target's {root pathspecs} and open the form.
# Returns the window path, or "" (with a status note) when not under git.
proc libmgr::do_history {lib cell {view {}}} {
  if {[catch {libmgr::git_target $lib $cell $view} res]} { libmgr::status "history: $res"; return "" }
  lassign $res root ps
  return [libmgr::history_dialog "History — [libmgr::cv_label $lib $cell $view]" $root $ps]
}
proc libmgr::do_history_view {lib cell view} { return [libmgr::do_history $lib $cell $view] }
proc libmgr::do_history_cell {lib cell}      { return [libmgr::do_history $lib $cell {}] }
proc libmgr::do_history_lib {lib} {
  set path [library_resolve $lib]
  if {$path eq {}} { libmgr::status "history: no such library: $lib"; return "" }
  set ctx [lib_git_context $path]
  if {$ctx eq {}} { libmgr::status "history: $lib is not under git revision control"; return "" }
  lassign $ctx root pathspec
  return [libmgr::history_dialog "History — $lib" $root [list $pathspec]]
}

# --- ctx_* handlers (gather input via dialogs, then delegate to do_*) ---------
proc libmgr::ctx_show_checkouts {} {
  variable sel_lib
  if {$sel_lib eq {}} { libmgr::status "select a library first"; return }
  libmgr::do_show_checkouts $sel_lib
}
proc libmgr::ctx_checkin_lib {} {
  variable sel_lib
  if {$sel_lib eq {}} { libmgr::status "select a library first"; return }
  set msg [libmgr::commit_dialog "Check in library '$sel_lib'"]
  if {$msg eq {}} return
  libmgr::do_checkin_lib $sel_lib $msg
}
proc libmgr::ctx_history_lib {} {
  variable sel_lib
  if {$sel_lib eq {}} { libmgr::status "select a library first"; return }
  libmgr::do_history_lib $sel_lib
}
proc libmgr::ctx_history_cell {} {
  set lc [libmgr::current_cell]; if {$lc eq {}} return
  lassign $lc lib cell; libmgr::do_history_cell $lib $cell
}
proc libmgr::ctx_history_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  libmgr::do_history_view $sel_lib $sel_cell $v
}
proc libmgr::ctx_checkout_cell {} {
  set lc [libmgr::current_cell]; if {$lc eq {}} return
  lassign $lc lib cell; libmgr::do_checkout $lib $cell
}
proc libmgr::ctx_checkin_cell {} {
  set lc [libmgr::current_cell]; if {$lc eq {}} return
  lassign $lc lib cell
  set msg [libmgr::commit_dialog "Check in '$lib/$cell'"]
  if {$msg eq {}} return
  libmgr::do_checkin $lib $cell {} $msg
}
proc libmgr::ctx_cancel_checkout_cell {} {
  set lc [libmgr::current_cell]; if {$lc eq {}} return
  lassign $lc lib cell
  if {[libmgr::confirm_cancel [libmgr::cv_label $lib $cell]]} { libmgr::do_cancel_checkout $lib $cell }
}
proc libmgr::ctx_checkout_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  libmgr::do_checkout $sel_lib $sel_cell $v
}
proc libmgr::ctx_checkin_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  set msg [libmgr::commit_dialog "Check in '[libmgr::cv_label $sel_lib $sel_cell $v]'"]
  if {$msg eq {}} return
  libmgr::do_checkin $sel_lib $sel_cell $v $msg
}
proc libmgr::ctx_cancel_checkout_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  if {[libmgr::confirm_cancel [libmgr::cv_label $sel_lib $sel_cell $v]]} {
    libmgr::do_cancel_checkout $sel_lib $sel_cell $v
  }
}

proc libmgr::confirm_cancel {what} {
  set ans [tk_messageBox -parent .libmgr -type yesno -icon warning -title "Cancel checkout" \
    -message "Cancel checkout of '$what'?\n\nThis rolls the datafile(s) back to the last committed version (HEAD); uncommitted edits are lost."]
  return [expr {$ans eq "yes"}]
}

# Multiline commit-comment dialog. Returns the trimmed message, or {} on Cancel /
# empty (every check-in goes through this).
proc libmgr::commit_dialog {title} {
  variable dlg_done
  set d .libmgr.cm
  catch {destroy $d}
  toplevel $d
  wm title $d $title
  wm transient $d .libmgr
  ttk::label $d.l -text "Commit message:" -anchor w
  text $d.t -width 56 -height 8 -wrap word
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l -row 0 -column 0 -sticky we  -padx 6 -pady {6 2}
  grid $d.t -row 1 -column 0 -sticky nsew -padx 6 -pady 2
  grid $d.b -row 2 -column 0 -pady 6
  grid rowconfigure $d 1 -weight 1
  grid columnconfigure $d 0 -weight 1
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.t
  vwait libmgr::dlg_done
  set res {}
  if {$dlg_done == 1} { set res [string trim [$d.t get 1.0 {end - 1 chars}]] }
  catch {destroy $d}
  return $res
}

# --- copy / rename (destination library + new name dialog) ---
# RMB > Copy on a cell now opens the Cadence-style Copy form (src/copy_form.tcl,
# doc/claude/specs/copy_hierarchical.md) instead of the two-field cell_dialog.
# It returns a PLAN dict. Pass 1 executes only the plan the old dialog could
# already express — flat copy, all views — and reports the rest as not yet
# implemented; the plan itself is the pass-2 handoff. cell_dialog stays as-is:
# Rename still uses it.
proc libmgr::ctx_copy_cell {} {
  set lc [libmgr::current_cell]
  if {$lc eq {}} return
  lassign $lc lib cell
  set plan {}
  if {[catch {copyform::open $lib $cell} plan]} { libmgr::status "copy form failed: $plan"; return }
  if {$plan eq {}} return
  lassign [dict get $plan dst] dl dc
  if {[dict get $plan hier]} {
    libmgr::status "hierarchical copy not implemented yet (pass 1: form only) — $lib/$cell -> $dl/$dc"
    return
  }
  if {[dict get $plan viewmode] ne "all"} {
    libmgr::status "per-view copy not implemented yet (pass 1: form only) — views: [join [dict get $plan views] { }]"
    return
  }
  libmgr::do_copy_cell $lib $cell $dl $dc
}
proc libmgr::do_copy_cell {sl sc dl dc} {
  if {[catch {library_copy_cell $sl $sc $dl $dc} e]} { libmgr::status "copy failed: $e"; return 0 }
  libmgr::refresh_after $dl $dc
  libmgr::status "copied $sl/$sc -> $dl/$dc"
  xschem log_action [list libmgr::do_copy_cell $sl $sc $dl $dc]
  return 1
}

proc libmgr::ctx_rename_cell {} {
  set lc [libmgr::current_cell]
  if {$lc eq {}} return
  lassign $lc lib cell
  set r [libmgr::cell_dialog "Rename cell" $lib $cell]
  if {$r eq {}} return
  lassign $r dl dc
  libmgr::do_rename_cell $lib $cell $dl $dc
}
proc libmgr::do_rename_cell {sl sc dl dc} {
  if {[catch {library_rename_cell $sl $sc $dl $dc} e]} { libmgr::status "rename failed: $e"; return 0 }
  libmgr::refresh_after $dl $dc
  libmgr::status "renamed $sl/$sc -> $dl/$dc"
  xschem log_action [list libmgr::do_rename_cell $sl $sc $dl $dc]
  return 1
}

# --- new cell / new library ---
proc libmgr::ctx_new_cell {} {
  variable sel_lib
  if {$sel_lib eq {}} { libmgr::status "select a library first"; return }
  set name [libmgr::simple_prompt "New cell in $sel_lib" "Cell name:" {}]
  if {$name eq {}} return
  libmgr::do_new_cell $sel_lib $name
}
proc libmgr::do_new_cell {lib cell} {
  if {[catch {library_new_cell $lib $cell} e]} { libmgr::status "new cell failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell
  libmgr::status "created cell $lib/$cell (schematic view)"
  xschem log_action [list libmgr::do_new_cell $lib $cell]
  return 1
}

proc libmgr::ctx_new_library {} {
  set r [libmgr::newlib_dialog]
  if {$r eq {}} return
  lassign $r name path
  libmgr::do_new_library $name $path
}
proc libmgr::do_new_library {name path} {
  if {[catch {library_new $name $path} e]} { libmgr::status "new library failed: $e"; return 0 }
  libmgr::refresh_after $name
  libmgr::status "created library $name"
  xschem log_action [list libmgr::do_new_library $name $path]
  return 1
}

proc libmgr::ctx_unregister_lib {} {
  variable sel_lib
  if {$sel_lib eq {}} return
  set ans [tk_messageBox -parent .libmgr -type yesno -icon question -title "Remove from list" \
    -message "Remove library '$sel_lib' from the registry?\n\nFiles on disk are NOT deleted."]
  if {$ans eq "yes"} { libmgr::do_unregister $sel_lib }
}
proc libmgr::do_unregister {lib} {
  if {[catch {library_unregister $lib} e]} { libmgr::status "remove failed: $e"; return 0 }
  libmgr::refresh_after
  libmgr::status "removed library $lib from the registry (files kept on disk)"
  xschem log_action [list libmgr::do_unregister $lib]
  return 1
}

# --- modal dialogs ---------------------------------------------------------
# Destination library (combobox) + new cell name (entry). Returns {lib cell} or
# {} on cancel / empty name.
proc libmgr::cell_dialog {title srclib srccell} {
  variable dlg_done
  set d .libmgr.cd
  catch {destroy $d}
  toplevel $d
  wm title $d $title
  wm transient $d .libmgr
  ttk::label $d.l1 -text "Destination library:"
  ttk::combobox $d.lib -state readonly -values [libmgr::lib_names]
  $d.lib set $srclib
  ttk::label $d.l2 -text "New cell name:"
  ttk::entry $d.cell -width 28
  $d.cell insert 0 $srccell
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l1 $d.lib  -sticky w -padx 6 -pady 4
  grid $d.l2 $d.cell -sticky w -padx 6 -pady 4
  grid $d.b  -        -pady 6
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.cell; $d.cell selection range 0 end
  vwait libmgr::dlg_done
  set ok $dlg_done
  set res {}
  if {$ok == 1} {
    set name [string trim [$d.cell get]]
    if {$name ne {}} { set res [list [$d.lib get] $name] }
  }
  catch {destroy $d}
  return $res
}

# Single labelled entry. Returns the trimmed value, or {} on cancel / empty.
proc libmgr::simple_prompt {title label {default {}}} {
  variable dlg_done
  set d .libmgr.sp
  catch {destroy $d}
  toplevel $d
  wm title $d $title
  wm transient $d .libmgr
  ttk::label $d.l -text $label
  ttk::entry $d.e -width 28
  $d.e insert 0 $default
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l $d.e -sticky w -padx 6 -pady 4
  grid $d.b -    -pady 6
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.e; $d.e selection range 0 end
  vwait libmgr::dlg_done
  set ok $dlg_done
  set res {}
  if {$ok == 1} { set res [string trim [$d.e get]] }
  catch {destroy $d}
  return $res
}

# Folder chooser for the New-library Directory field. Seeds the dialog at the
# current entry value (if it names a real dir), else the primary library.defs dir
# (where a blank field would create the library), else the cwd. Writes the chosen
# directory back into the entry; leaves it untouched on Cancel.
proc libmgr::newlib_browse {entry} {
  set start [string trim [$entry get]]
  if {$start eq {} || ![file isdirectory $start]} {
    set defs [library_primary_defs_file]
    if {$defs ne {} && [file isfile $defs]} {
      set start [file dirname $defs]
    } else {
      set start [pwd]
    }
  }
  set dir [tk_chooseDirectory -parent .libmgr.nl -mustexist 0 \
    -title "New library directory" -initialdir $start]
  if {$dir ne {}} { $entry delete 0 end; $entry insert 0 $dir }
}

# Library name + directory. Returns {name path} or {} on cancel / empty name.
proc libmgr::newlib_dialog {} {
  variable dlg_done
  set d .libmgr.nl
  catch {destroy $d}
  toplevel $d
  wm title $d "New library"
  wm transient $d .libmgr
  ttk::label $d.l1 -text "Library name:"
  ttk::entry $d.name -width 28
  ttk::label $d.l2 -text "Directory (blank = in same directory as library.defs):"
  ttk::frame $d.pf
  ttk::entry $d.pf.path -width 32
  ttk::button $d.pf.browse -text "Browse…" -command \
    [list libmgr::newlib_browse $d.pf.path]
  pack $d.pf.path -side left
  pack $d.pf.browse -side left -padx {4 0}
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l1 $d.name -sticky w -padx 6 -pady 4
  grid $d.l2 $d.pf   -sticky w -padx 6 -pady 4
  grid $d.b  -       -pady 6
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.name
  vwait libmgr::dlg_done
  set ok $dlg_done
  set res {}
  if {$ok == 1} {
    set name [string trim [$d.name get]]
    if {$name ne {}} { set res [list $name [string trim [$d.pf.path get]]] }
  }
  catch {destroy $d}
  return $res
}

# --- view-level context actions --------------------------------------------
proc libmgr::ctx_rename_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  set nv [libmgr::simple_prompt "Rename view" "New view name:" $v]
  if {$nv eq {}} return
  libmgr::do_rename_view $sel_lib $sel_cell $v $nv
}
proc libmgr::do_rename_view {lib cell oldv newv} {
  if {[catch {library_rename_view $lib $cell $oldv $newv} e]} { libmgr::status "rename failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell $newv
  libmgr::status "renamed view $lib/$cell/$oldv -> $newv"
  xschem log_action [list libmgr::do_rename_view $lib $cell $oldv $newv]
  return 1
}

proc libmgr::ctx_copy_view {} {
  variable sel_lib; variable sel_cell
  set v [libmgr::cursel .libmgr.pw.view.lb]
  if {$sel_lib eq {} || $sel_cell eq {} || $v eq {}} return
  set r [libmgr::view_dialog "Copy view" $sel_lib $sel_cell $v]
  if {$r eq {}} return
  lassign $r dl dc dv
  libmgr::do_copy_view $sel_lib $sel_cell $v $dl $dc $dv
}
proc libmgr::do_copy_view {sl sc sv dl dc dv} {
  if {[catch {library_copy_view $sl $sc $sv $dl $dc $dv} e]} { libmgr::status "copy failed: $e"; return 0 }
  libmgr::refresh_after $dl $dc $dv
  libmgr::status "copied view $sl/$sc/$sv -> $dl/$dc/$dv"
  xschem log_action [list libmgr::do_copy_view $sl $sc $sv $dl $dc $dv]
  return 1
}

proc libmgr::ctx_new_view {} {
  variable sel_lib; variable sel_cell
  if {$sel_lib eq {} || $sel_cell eq {}} { libmgr::status "select a cell first"; return }
  set r [libmgr::newview_dialog $sel_lib $sel_cell]
  if {$r eq {}} return
  lassign $r name type
  libmgr::do_new_view $sel_lib $sel_cell $name $type
}
proc libmgr::do_new_view {lib cell view type} {
  if {[catch {library_new_view $lib $cell $view $type} e]} { libmgr::status "new view failed: $e"; return 0 }
  libmgr::refresh_after $lib $cell $view
  libmgr::status "created view $lib/$cell/$view ($type)"
  xschem log_action [list libmgr::do_new_view $lib $cell $view $type]
  return 1
}

# Destination library (combobox) + cell + new view name. Returns {lib cell view}
# or {} on cancel / empty cell-or-view.
proc libmgr::view_dialog {title srclib srccell srcview} {
  variable dlg_done
  set d .libmgr.vd
  catch {destroy $d}
  toplevel $d
  wm title $d $title
  wm transient $d .libmgr
  ttk::label $d.l1 -text "Destination library:"
  ttk::combobox $d.lib -state readonly -values [libmgr::lib_names]
  $d.lib set $srclib
  ttk::label $d.l2 -text "Destination cell:"
  ttk::entry $d.cell -width 28
  $d.cell insert 0 $srccell
  ttk::label $d.l3 -text "New view name:"
  ttk::entry $d.view -width 28
  $d.view insert 0 $srcview
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l1 $d.lib  -sticky w -padx 6 -pady 4
  grid $d.l2 $d.cell -sticky w -padx 6 -pady 4
  grid $d.l3 $d.view -sticky w -padx 6 -pady 4
  grid $d.b  -       -pady 6
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.view; $d.view selection range 0 end
  vwait libmgr::dlg_done
  set ok $dlg_done
  set res {}
  if {$ok == 1} {
    set c [string trim [$d.cell get]]; set v [string trim [$d.view get]]
    if {$c ne {} && $v ne {}} { set res [list [$d.lib get] $c $v] }
  }
  catch {destroy $d}
  return $res
}

# View name + editor type. Returns {name type} or {}.
#   schematic/symbol  empty .sch/.sym body
#   verilog/veriloga  a source file seeded with a module header built from the
#                     cell's symbol pins (doc/claude/specs/mixed_signal_signal_browser.md §B4)
#   ngspice_state1    an ASE simulation-state view (doc/claude/specs/ase_l.md)
# The combobox values must stay a subset of what view_ext_of_type creates —
# library_new_view now errors on an unknown type instead of quietly writing a
# .sch, so an entry added here without a table row is a visible failure.
proc libmgr::newview_dialog {lib cell} {
  variable dlg_done
  set d .libmgr.nv2
  catch {destroy $d}
  toplevel $d
  wm title $d "New view in $cell"
  wm transient $d .libmgr
  ttk::label $d.l1 -text "View name:"
  ttk::entry $d.name -width 28
  ttk::label $d.l2 -text "Editor type:"
  ttk::combobox $d.type -state readonly -values {schematic symbol verilog veriloga ngspice_state1}
  $d.type set schematic
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set libmgr::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set libmgr::dlg_done 0}
  pack $d.b.ok $d.b.cancel -side left -padx 4
  grid $d.l1 $d.name -sticky w -padx 6 -pady 4
  grid $d.l2 $d.type -sticky w -padx 6 -pady 4
  grid $d.b  -       -pady 6
  bind $d <Return> {set libmgr::dlg_done 1}
  bind $d <Escape> {set libmgr::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.name
  vwait libmgr::dlg_done
  set ok $dlg_done
  set res {}
  if {$ok == 1} {
    set n [string trim [$d.name get]]
    if {$n ne {}} { set res [list $n [$d.type get]] }
  }
  catch {destroy $d}
  return $res
}

# convenience global alias
proc library_manager {} { libmgr::open }
