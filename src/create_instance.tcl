# create_instance.tcl — Cadence-style "Create Instance" library browser.
#
# A modeless three-column Library / Cell / View browser (like the Library Manager)
# whose View column is restricted to SYMBOL views: picking one and pressing Create
# attaches that symbol to the cursor for placement (xschem place_symbol), and the
# form stays open so several instances can be placed in a row. A "Legacy Xschem"
# button drops to the classic flat symbol-picker dialog (xschem place_symbol, no
# arg). The window is a singleton, opened via `xschem create_instance` (logged /
# bindable). See specs/cadence_create_instance.md.

namespace eval mkinst {
  variable sel_lib  ""
  variable sel_cell ""
}

# the (single) listbox selection text, or "" if nothing selected
proc mkinst::cursel {lb} {
  set i [$lb curselection]
  if {$i eq {}} { return {} }
  return [$lb get [lindex $i 0]]
}

proc mkinst::status {msg} { catch {.mkinst.status configure -text $msg} }

# Bring the (existing) window to the front with keyboard focus. Window managers
# with focus-stealing prevention refuse raise/focus on an already-open window but
# grant it to a freshly mapped one, so re-map it; preserve geometry so it doesn't
# jump. Same pattern as libmgr::raise_to_front (specs/library_manager_launch.md).
proc mkinst::raise_to_front {} {
  set w .mkinst
  if {![winfo exists $w]} return
  if {[winfo ismapped $w]} {
    set geo [wm geometry $w]
    wm withdraw $w
    wm deiconify $w
    catch {wm geometry $w $geo}
  } else {
    catch {wm deiconify $w}
  }
  raise $w
  catch {focus -force $w.pw.lib.lb}
  after idle [list mkinst::refocus $w]
}
proc mkinst::refocus {w} {
  if {[winfo exists $w]} { catch {focus -force $w.pw.lib.lb} }
}

proc mkinst::open {} {
  set w .mkinst
  if {[winfo exists $w]} {
    mkinst::raise_to_front
    mkinst::populate_libs
    return
  }
  toplevel $w
  wm title $w "Create Instance"
  wm geometry $w 640x420

  ttk::panedwindow $w.pw -orient horizontal
  pack $w.pw -side top -fill both -expand 1
  foreach {col title} {lib Library cell Cell view View} {
    set f [ttk::frame $w.pw.$col]
    ttk::label $f.h -text $title -anchor w -padding {4 2}
    listbox $f.lb -exportselection 0 -activestyle dotbox \
            -yscrollcommand "$f.sb set" -width 16 -height 18
    ttk::scrollbar $f.sb -orient vertical -command "$f.lb yview"
    grid $f.h  -row 0 -column 0 -columnspan 2 -sticky we
    grid $f.lb -row 1 -column 0 -sticky nsew
    grid $f.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $f 1 -weight 1
    grid columnconfigure $f 0 -weight 1
    $w.pw add $f -weight 1
  }

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} -text "select a symbol to instantiate"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.create -text "Create"        -command mkinst::create -state disabled
  ttk::button $w.b.legacy -text "Legacy Xschem" -command mkinst::legacy
  ttk::button $w.b.close  -text "Close"         -command "destroy $w"
  pack $w.b.create $w.b.legacy -side left -padx 4 -pady 4
  pack $w.b.close -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  bind $w.pw.lib.lb  <<ListboxSelect>> mkinst::on_lib
  bind $w.pw.cell.lb <<ListboxSelect>> mkinst::on_cell
  bind $w.pw.cell.lb <Double-1>        mkinst::create
  bind $w.pw.view.lb <Double-1>        mkinst::create

  mkinst::populate_libs
  mkinst::raise_to_front
}

proc mkinst::populate_libs {} {
  set lb .mkinst.pw.lib.lb
  if {![winfo exists $lb]} return
  $lb delete 0 end
  set names {}
  foreach pair [xschem libraries] { lappend names [lindex $pair 0] }
  foreach n [lsort $names] { $lb insert end $n }
  .mkinst.pw.cell.lb delete 0 end
  .mkinst.pw.view.lb delete 0 end
  set mkinst::sel_lib  ""
  set mkinst::sel_cell ""
  .mkinst.b.create configure -state disabled
}

proc mkinst::on_lib {} {
  set mkinst::sel_lib [mkinst::cursel .mkinst.pw.lib.lb]
  set mkinst::sel_cell ""
  set cl .mkinst.pw.cell.lb
  $cl delete 0 end
  .mkinst.pw.view.lb delete 0 end
  .mkinst.b.create configure -state disabled
  if {$mkinst::sel_lib eq {}} return
  foreach c [xschem lib_cells $mkinst::sel_lib] { $cl insert end $c }
}

# symbol views of <lib/cell>: those whose datafile resolves to a .sym
proc mkinst::symbol_views {lib cell} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    if {[string match {*.sym} [xschem cellview_path "$lib/$cell" $v]]} { lappend out $v }
  }
  return $out
}

proc mkinst::on_cell {} {
  set mkinst::sel_cell [mkinst::cursel .mkinst.pw.cell.lb]
  set vl .mkinst.pw.view.lb
  $vl delete 0 end
  .mkinst.b.create configure -state disabled
  if {$mkinst::sel_lib eq {} || $mkinst::sel_cell eq {}} return
  set sv [mkinst::symbol_views $mkinst::sel_lib $mkinst::sel_cell]
  foreach v $sv { $vl insert end $v }
  if {[llength $sv] > 0} {
    # default-select the canonical "symbol" view, else the first symbol view
    set i [lsearch -exact $sv symbol]
    if {$i < 0} { set i 0 }
    $vl selection set $i; $vl activate $i
    .mkinst.b.create configure -state normal
    mkinst::status "ready: $mkinst::sel_lib/$mkinst::sel_cell ([lindex $sv $i])"
  } else {
    mkinst::status "no symbol view for $mkinst::sel_lib/$mkinst::sel_cell"
  }
}

# Place the selected symbol view as an instance (attach to cursor). The form stays
# open and does NOT grab focus back, so the canvas receives the placement clicks.
proc mkinst::create {args} {
  if {$mkinst::sel_lib eq {} || $mkinst::sel_cell eq {}} return
  set v [mkinst::cursel .mkinst.pw.view.lb]
  if {$v eq {}} { set v symbol }
  set f [xschem cellview_path "$mkinst::sel_lib/$mkinst::sel_cell" $v]
  if {$f eq {} || ![string match {*.sym} $f]} {
    mkinst::status "no symbol view for $mkinst::sel_lib/$mkinst::sel_cell"
    return
  }
  xschem place_symbol $f
  mkinst::status "placing $mkinst::sel_lib/$mkinst::sel_cell ($v) - click on the canvas"
}

# Drop to the classic flat symbol-picker dialog (unchanged behavior).
proc mkinst::legacy {} {
  xschem place_symbol
}
