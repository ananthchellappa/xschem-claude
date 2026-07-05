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
proc locate_selected_in_libmgr {} {
  set k [cadence::selkind]
  switch -- [lindex $k 0] {
    inst {
      if {[catch {xschem get_inst_lcv} lcv] || $lcv eq {}} {
        ciw_echo "cannot resolve the selected instance's cell ($lcv)" error ; return
      }
      xschem library_manager $lcv
    }
    text {
      set lc [cadence::first_libcell [lindex $k 2]]
      if {$lc eq {}} { ciw_echo "no library/cell (lib/cell) in the selected note" error ; return }
      xschem library_manager $lc
    }
    none {
      set lcv [schematic_cellview [xschem get schname]]
      if {$lcv eq {}} { ciw_echo "current cell is not in a registered library" error ; return }
      xschem library_manager [lrange $lcv 0 1]
    }
    default {
      ciw_echo "select one instance, one lib/cell text note, or nothing (for the current cell)" error
    }
  }
}


