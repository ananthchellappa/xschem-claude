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
  variable new_window 1 ;# open schematics in a new window/tab (vs the current one)
}

# Bring the (existing) Library Manager window to the front AND give it the
# keyboard focus. Plain `focus` cannot move focus across toplevels, so when
# another window (e.g. the CIW) is the active one it would be ignored -- we use
# `focus -force`. It is re-asserted at idle so this also works for a window that
# was just created and is not yet mapped. See specs/library_manager_launch.md.
proc libmgr::raise_to_front {} {
  set w .libmgr
  if {![winfo exists $w]} return
  # Window managers with focus-stealing prevention refuse raise/focus on an
  # ALREADY-OPEN window, but grant focus to a freshly MAPPED one (which is why
  # opening from closed gets focus and re-launching does not). So re-map an open
  # window (withdraw + deiconify) to make the WM treat it as a fresh map and give
  # it focus; preserve geometry so it doesn't jump. See
  # specs/library_manager_launch.md.
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
  after idle [list libmgr::refocus $w]
}
proc libmgr::refocus {w} {
  if {[winfo exists $w]} { catch {focus -force $w.pw.lib.lb} }
}

proc libmgr::open {} {
  set w .libmgr
  if {[winfo exists $w]} {
    # single window: bring the existing one forward and focus it rather than
    # building a second one. See specs/library_manager_launch.md.
    libmgr::raise_to_front
    libmgr::refresh
    return
  }
  toplevel $w
  wm title $w "Library Manager"
  wm geometry $w 760x460

  ttk::panedwindow $w.pw -orient horizontal
  pack $w.pw -side top -fill both -expand 1

  # one column = header label + listbox + scrollbar, in a frame added to the pane
  foreach {col title} {lib Library cell Cell view View} {
    set f [ttk::frame $w.pw.$col]
    ttk::label $f.h -text $title -anchor w -padding {4 2}
    listbox $f.lb -exportselection 0 -activestyle dotbox \
            -yscrollcommand "$f.sb set" -width 18 -height 20
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

  bind $w.pw.lib.lb  <<ListboxSelect>> libmgr::on_lib
  bind $w.pw.cell.lb <<ListboxSelect>> libmgr::on_cell
  bind $w.pw.view.lb <<ListboxSelect>> libmgr::on_view
  bind $w.pw.cell.lb <Double-1>        libmgr::open_view
  bind $w.pw.view.lb <Double-1>        libmgr::open_view

  libmgr::build_menus $w
  bind $w.pw.lib.lb  <Button-3> {libmgr::ctx_post lib  %y %X %Y}
  bind $w.pw.cell.lb <Button-3> {libmgr::ctx_post cell %y %X %Y}
  bind $w.pw.view.lb <Button-3> {libmgr::ctx_post view %y %X %Y}

  libmgr::populate_libs
  # a freshly created window should also come up focused, even if another
  # toplevel (the CIW, the main window) was active when it was launched.
  libmgr::raise_to_front
}

# Per-column right-click menus, built once and re-targeted on each click.
proc libmgr::build_menus {w} {
  catch {destroy $w.mlib $w.mcell $w.mview}

  menu $w.mlib -tearoff 0
  $w.mlib add command -label "New cell…"    -command libmgr::ctx_new_cell
  $w.mlib add command -label "New library…" -command libmgr::ctx_new_library
  $w.mlib add separator
  $w.mlib add command -label "Remove from list" -command libmgr::ctx_unregister_lib
  $w.mlib add separator
  $w.mlib add command -label "Refresh" -command libmgr::refresh

  menu $w.mcell -tearoff 0
  $w.mcell add command -label "Open"             -command libmgr::open_view
  $w.mcell add command -label "Open (read-only)" -command libmgr::open_view_ro
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
  $w.mview add command -label "Copy…"   -command libmgr::ctx_copy_view
  $w.mview add command -label "Rename…" -command libmgr::ctx_rename_view
  $w.mview add command -label "New view…" -command libmgr::ctx_new_view
  $w.mview add separator
  $w.mview add command -label "Delete view" -command libmgr::ctx_delete_view
}

# Right-click in column $col: select the row under the pointer, sync the panes,
# then post that column's menu.
proc libmgr::ctx_post {col y rootx rooty} {
  set lb .libmgr.pw.$col.lb
  set idx [$lb nearest $y]
  if {$idx >= 0 && [lindex [$lb bbox $idx] 1] ne {}} {
    $lb selection clear 0 end; $lb selection set $idx; $lb activate $idx
    switch -- $col { lib {libmgr::on_lib} cell {libmgr::on_cell} view {libmgr::on_view} }
  }
  catch {tk_popup .libmgr.m$col $rootx $rooty}
}

# helper: the selected text in a listbox, or "" if none
proc libmgr::cursel {lb} {
  set i [$lb curselection]
  if {$i eq {}} { return "" }
  return [$lb get [lindex $i 0]]
}

proc libmgr::populate_libs {} {
  variable sel_lib; variable sel_cell
  set lb .libmgr.pw.lib.lb
  $lb delete 0 end
  foreach pair [xschem libraries] { $lb insert end [lindex $pair 0] }
  .libmgr.pw.cell.lb delete 0 end
  .libmgr.pw.view.lb delete 0 end
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
  set cl .libmgr.pw.cell.lb
  $cl delete 0 end
  .libmgr.pw.view.lb delete 0 end
  if {$sel_lib ne ""} {
    foreach c [xschem lib_cells $sel_lib] { $cl insert end $c }
  }
  .libmgr.status configure -text "library: $sel_lib"
}

# cell selected -> fill the View column
proc libmgr::on_cell {args} {
  variable sel_lib; variable sel_cell
  set sel_cell [libmgr::cursel .libmgr.pw.cell.lb]
  set vl .libmgr.pw.view.lb
  $vl delete 0 end
  if {$sel_lib ne "" && $sel_cell ne ""} {
    foreach v [xschem cell_views $sel_lib $sel_cell] { $vl insert end $v }
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

# open the selected view in its editor (schematic OR symbol), in a new window or
# the current one per the "New window" checkbox.
proc libmgr::open_view {args} {
  variable new_window
  set lcv [libmgr::current_view]
  if {$lcv eq {}} { return 0 }
  lassign $lcv lib cell view
  set f [xschem cellview_path "$lib/$cell" $view]
  if {$f eq {}} { .libmgr.status configure -text "no $view view for $lib/$cell"; return 0 }
  # action-log: record the replayable open (the bare load_new_window/load command
  # is otherwise the silent "replay form", so a Library Manager open would not be
  # logged to the CIW / Xschem.log without this).
  if {$new_window} {
    xschem load_new_window $f
    xschem log_action "xschem load_new_window {$f}"
  } else {
    xschem load $f
    xschem log_action "xschem load {$f}"
  }
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

proc libmgr::status {msg} { catch {.libmgr.status configure -text $msg} }

proc libmgr::lib_names {} {
  set out {}
  foreach pair [xschem libraries] { lappend out [lindex $pair 0] }
  return $out
}

# Rebuild the Library pane, then restore the given lib (and cell) selection so
# the panes reflect a just-completed mutation.
proc libmgr::refresh_after {{lib {}} {cell {}} {view {}}} {
  variable sel_lib; variable sel_cell
  if {![winfo exists .libmgr]} return
  set ll .libmgr.pw.lib.lb
  $ll delete 0 end
  foreach name [libmgr::lib_names] { $ll insert end $name }
  .libmgr.pw.cell.lb delete 0 end
  .libmgr.pw.view.lb delete 0 end
  set sel_lib ""; set sel_cell ""
  if {$lib eq {}} return
  set i [lsearch -exact [$ll get 0 end] $lib]
  if {$i < 0} return
  $ll selection clear 0 end; $ll selection set $i; $ll activate $i
  libmgr::on_lib
  if {$cell eq {}} return
  set cl .libmgr.pw.cell.lb
  set j [lsearch -exact [$cl get 0 end] $cell]
  if {$j < 0} return
  $cl selection clear 0 end; $cl selection set $j; $cl activate $j
  libmgr::on_cell
  if {$view eq {}} return
  set vl .libmgr.pw.view.lb
  set k [lsearch -exact [$vl get 0 end] $view]
  if {$k < 0} return
  $vl selection clear 0 end; $vl selection set $k; $vl activate $k
  libmgr::on_view
}

# Open (read-only): open the view, then force the opened window into read-only
# (file-protected) mode. A plain Open already falls back to read-only on its own
# when the file is not writable; this forces it even for writable files.
proc libmgr::open_view_ro {} {
  set lcv [libmgr::current_view]
  if {$lcv eq {}} return
  if {![libmgr::open_view]} return
  xschem set readonly 1
  xschem log_action "xschem set readonly 1"
  lassign $lcv lib cell view
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
  return 1
}

# --- copy / rename (destination library + new name dialog) ---
proc libmgr::ctx_copy_cell {} {
  set lc [libmgr::current_cell]
  if {$lc eq {}} return
  lassign $lc lib cell
  set r [libmgr::cell_dialog "Copy cell" $lib $cell]
  if {$r eq {}} return
  lassign $r dl dc
  libmgr::do_copy_cell $lib $cell $dl $dc
}
proc libmgr::do_copy_cell {sl sc dl dc} {
  if {[catch {library_copy_cell $sl $sc $dl $dc} e]} { libmgr::status "copy failed: $e"; return 0 }
  libmgr::refresh_after $dl $dc
  libmgr::status "copied $sl/$sc -> $dl/$dc"
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

# View name + editor type (schematic|symbol). Returns {name type} or {}.
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
  ttk::combobox $d.type -state readonly -values {schematic symbol}
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
