# create_instance.tcl — Cadence-style "Create Instance" library browser.
#
# A modeless three-column Library / Cell / View browser (like the Library Manager)
# whose View column is restricted to SYMBOL views. It is a *selector that arms a
# live preview*, not a click-Create dialog: picking a cell + symbol view arms the
# symbol for placement (xschem place_symbol) so the preview follows the cursor on
# the canvas; xschem's native place loop keeps it armed for repeated drops. Esc
# both ends placement and dismisses the form. Re-launching restores the last
# selection and re-arms it. A "Legacy Xschem" button drops to the classic flat
# symbol-picker dialog. Window is a singleton, opened via `xschem create_instance`
# (logged / bindable). See specs/cadence_create_instance.md.

namespace eval mkinst {
  variable sel_lib  ""
  variable sel_cell ""
  # most recently armed selection, restored on reopen
  variable last_lib  ""
  variable last_cell ""
  variable last_view ""
}

proc mkinst::cursel {lb} {
  set i [$lb curselection]
  if {$i eq {}} { return {} }
  return [$lb get [lindex $i 0]]
}

proc mkinst::status {msg} { catch {.mkinst.status configure -text $msg} }

proc mkinst::placing {} { return [expr {[xschem get ui_state] & 8192}] }
proc mkinst::abort_if_placing {} { if {[mkinst::placing]} { catch {xschem abort_operation} } }

# Bring the (existing) window to the front with keyboard focus; re-map to defeat
# focus-stealing prevention (same pattern as libmgr::raise_to_front,
# specs/library_manager_launch.md).
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
    mkinst::restore_last
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

  ttk::label $w.status -anchor w -relief sunken -padding {4 2} \
    -text "pick a symbol - it arms for placement; Esc finishes"
  pack $w.status -side bottom -fill x

  ttk::frame $w.b
  ttk::button $w.b.legacy -text "Legacy Xschem" -command mkinst::legacy
  ttk::button $w.b.close  -text "Close"         -command "destroy $w"
  pack $w.b.legacy -side left -padx 4 -pady 4
  pack $w.b.close -side right -padx 4 -pady 4
  pack $w.b -side bottom -fill x

  bind $w.pw.lib.lb  <<ListboxSelect>> mkinst::on_lib
  bind $w.pw.cell.lb <<ListboxSelect>> mkinst::on_cell
  bind $w.pw.view.lb <<ListboxSelect>> mkinst::on_view

  # Esc ends placement AND dismisses the form, whether the canvas or the form has
  # focus. `break` on the canvas pre-empts the generic <KeyPress> -> C dispatcher.
  bind .drw <Key-Escape> {mkinst::escape; break}
  bind $w   <Key-Escape> {mkinst::escape}
  bind $w   <Destroy>    {if {{%W} eq {.mkinst}} {mkinst::on_destroy}}

  mkinst::populate_libs
  mkinst::raise_to_front
  mkinst::restore_last
}

# Esc / close: abort any armed placement and remove the canvas Esc binding so the
# default Esc behavior is restored.
proc mkinst::escape {} {
  mkinst::abort_if_placing
  catch {destroy .mkinst}
}
proc mkinst::on_destroy {} {
  catch {bind .drw <Key-Escape> {}}
  mkinst::abort_if_placing
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
}

proc mkinst::on_lib {} {
  set mkinst::sel_lib [mkinst::cursel .mkinst.pw.lib.lb]
  set mkinst::sel_cell ""
  set cl .mkinst.pw.cell.lb
  $cl delete 0 end
  .mkinst.pw.view.lb delete 0 end
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
  if {$mkinst::sel_lib eq {} || $mkinst::sel_cell eq {}} return
  set sv [mkinst::symbol_views $mkinst::sel_lib $mkinst::sel_cell]
  foreach v $sv { $vl insert end $v }
  if {[llength $sv] > 0} {
    set i [lsearch -exact $sv symbol]
    if {$i < 0} { set i 0 }
    $vl selection set $i; $vl activate $i
    mkinst::arm
  } else {
    mkinst::abort_if_placing
    mkinst::status "no symbol view for $mkinst::sel_lib/$mkinst::sel_cell"
  }
}

proc mkinst::on_view {} { mkinst::arm }

# A circuit is physical: a cell may not contain itself. A selection is recursive
# when its schematic view IS the schematic currently being edited.
proc mkinst::is_recursive {lib cell} {
  set sch [xschem cellview_path "$lib/$cell" schematic]
  if {$sch eq {}} { return 0 }
  set cur [xschem get schname]
  if {$cur eq {}} { return 0 }
  return [expr {[file normalize $sch] eq [file normalize $cur]}]
}

# Arm the selected symbol view for placement (preview attaches to the cursor on the
# canvas). Re-arming aborts the previous, undropped preview first. Records the
# selection so reopening can resume it.
proc mkinst::arm {} {
  if {$mkinst::sel_lib eq {} || $mkinst::sel_cell eq {}} return
  set v [mkinst::cursel .mkinst.pw.view.lb]
  if {$v eq {}} return
  set f [xschem cellview_path "$mkinst::sel_lib/$mkinst::sel_cell" $v]
  if {$f eq {} || ![string match {*.sym} $f]} {
    mkinst::abort_if_placing
    mkinst::status "no symbol view for $mkinst::sel_lib/$mkinst::sel_cell"
    return
  }
  if {[mkinst::is_recursive $mkinst::sel_lib $mkinst::sel_cell]} {
    mkinst::abort_if_placing
    mkinst::status "cannot instantiate $mkinst::sel_cell inside its own schematic (recursion)"
    return
  }
  mkinst::abort_if_placing
  xschem place_symbol $f
  set mkinst::last_lib  $mkinst::sel_lib
  set mkinst::last_cell $mkinst::sel_cell
  set mkinst::last_view $v
  mkinst::status "placing $mkinst::sel_lib/$mkinst::sel_cell ($v) - click to place; Esc to finish"
}

# Restore the most recently armed selection (on reopen) and re-arm its preview.
proc mkinst::restore_last {} {
  if {$mkinst::last_lib eq {}} return
  set ll .mkinst.pw.lib.lb
  set i [lsearch -exact [$ll get 0 end] $mkinst::last_lib]
  if {$i < 0} return
  $ll selection clear 0 end; $ll selection set $i; $ll activate $i
  mkinst::on_lib
  set cl .mkinst.pw.cell.lb
  set i [lsearch -exact [$cl get 0 end] $mkinst::last_cell]
  if {$i < 0} return
  $cl selection clear 0 end; $cl selection set $i; $cl activate $i
  mkinst::on_cell
  set vl .mkinst.pw.view.lb
  set i [lsearch -exact [$vl get 0 end] $mkinst::last_view]
  if {$i >= 0} {
    $vl selection clear 0 end; $vl selection set $i; $vl activate $i
    mkinst::on_view
  }
}

# Drop to the classic flat symbol-picker dialog (unchanged behavior).
proc mkinst::legacy {} {
  xschem place_symbol
}
