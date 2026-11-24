proc place_libmgr_selection {} {
  set sel [libmgr::selection]
  if {[llength $sel] < 2} { ciw_echo "select at least a cell in the Library Manager" error; return }
  lassign $sel lib cell view
  if {$view eq ""} { set view symbol }      ;# default to the symbol view
  set f [xschem cellview_path "$lib/$cell" $view]
  if {$f eq "" || ![string match *.sym $f]} { ciw_echo "no symbol view for $lib/$cell" error; return }
  ciform::set_fields [list $lib $cell $view]  ;# remember it for the Create Instance form
  xschem place_symbol $f                      ;# cursor preview; click to drop
}

# Ctrl-Alt-S: locate a cell in the Library Manager (which is raised). Branches on the
# selection (see doc/claude/specs/cadence_note_nav.md):
#   - one instance  -> its master (xschem get_inst_lcv);
#   - nothing        -> the cell currently being viewed (schematic_cellview);
#   - one text note  -> the first "lib/cell" token in the note.
#
# EVERY PRESS ENDS WITH THE LIBRARY MANAGER IN FRONT, HOLDING THE KEYBOARD
# (issue 1738). When there is a cell to locate, `xschem library_manager <cell>`
# raises the window, gives it the keyboard and selects the cell, as it always
# has. When there is none -- the schematic is an untitled one or is in no
# registered library, the selected instance or note names no library cell, or
# the selection is something else -- the same command without a cell brings the
# window forward the same way (and opens it when it is closed), and one line in
# the CIW says why nothing is located. The user's case was the first: the key
# pressed on untitled.sch to get a Library Manager that was behind other
# windows. Before, those four cases wrote the line and raised nothing.
proc locate_selected_in_libmgr {} {
  set k [cadence::selkind]
  set tag error
  switch -- [lindex $k 0] {
    inst {
      if {![catch {xschem get_inst_lcv} lcv] && $lcv ne {}} { xschem library_manager $lcv ; return }
      set why "cannot resolve the selected instance's cell ($lcv)"
    }
    text {
      set lc [cadence::first_libcell [lindex $k 2]]
      if {$lc ne {}} { xschem library_manager $lc ; return }
      set why "no library/cell (lib/cell) in the selected note"
    }
    none {
      set lcv [schematic_cellview [xschem get schname]]
      if {$lcv ne {}} { xschem library_manager [lrange $lcv 0 1] ; return }
      # not a mistake of the user's: this is how the key is used to get the window
      set why "current cell is not in a registered library"
      set tag result
    }
    default {
      set why "select one instance, one lib/cell text note, or nothing (for the current cell)"
    }
  }
  xschem library_manager
  ciw_echo "$why: Library Manager raised, nothing located" $tag
}


