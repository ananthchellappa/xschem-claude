proc dump_menu {w} {
  set out {}
  if {[catch {$w index end} last]} { return $out }
  if {$last eq {none} || $last eq {}} { return $out }
  for {set i 0} {$i <= $last} {incr i} {
    set type [$w type $i]
    if {$type eq {separator}} {
      lappend out [list separator {} {} {} {}]
      continue
    }
    set label [$w entrycget $i -label]
    set accel ""
    catch { set accel [$w entrycget $i -accelerator] }
    set var ""
    catch { set var [$w entrycget $i -variable] }
    set val ""
    catch { set val [$w entrycget $i -value] }
    lappend out [list $type $label $accel $var $val]
    if {$type eq {cascade}} {
      set sub [$w entrycget $i -menu]
      foreach child [dump_menu $sub] {
        lappend out [concat sub: $child]
      }
    }
  }
  return $out
}

set expected {
  {command Undo U {} {}}
  {command Redo Shift+U {} {}}
  {command Copy Ctrl+C {} {}}
  {command Cut Ctrl+X {} {}}
  {command Paste Ctrl+V {} {}}
  {command Delete Del {} {}}
  {command {Select all} Ctrl+A {} {}}
  {command {Duplicate objects} C {} {}}
  {command {Move objects} M {} {}}
  {command {Move objects stretching attached wires} Control+M {} {}}
  {command {Move objects adding wires to connected pins} Shift+M {} {}}
  {command {Horizontal Flip in place selected objects} Alt-F {} {}}
  {command {Vertical Flip in place selected objects} Alt-V {} {}}
  {command {Rotate in place selected objects} Alt-R {} {}}
  {command {Vertical Flip selected objects} Shift-V {} {}}
  {command {Horizontal Flip selected objects} Shift-F {} {}}
  {command {Rotate selected objects} Shift-R {} {}}
  {separator {} {} {} {}}
  {radiobutton {Unconstrained move} {} constr_mv 0}
  {radiobutton {Constrained Horizontal move} H constr_mv 1}
  {radiobutton {Constrained Vertical move} V constr_mv 2}
  {separator {} {} {} {}}
  {command {Push schematic} E {} {}}
  {command {Push symbol} I {} {}}
  {command Pop Ctrl+E {} {}}
}

update idletasks
if {![winfo exists .menubar.edit]} {
  puts "EDIT-MENU: ERROR .menubar.edit does not exist"
  flush stdout
  exit 2
}

proc run_compare {} {
  global expected
  set got [dump_menu .menubar.edit]
  set fail 0
  
  set n [expr {max([llength $got],[llength $expected])}]
  for {set i 0} {$i < $n} {incr i} {
    set g [lindex $got $i]
    set e [lindex $expected $i]
    if {$g ne $e} {
      puts "DIFF\[$i\]  got: {$g}   expected: {$e}"
      set fail 1
    }
  }
  if {$fail} { puts "EDIT-MENU: FAIL" } else { puts "EDIT-MENU: MATCH" }
  flush stdout
  exit [expr {$fail ? 1 : 0}]
}
run_compare
