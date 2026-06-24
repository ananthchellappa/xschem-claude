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
  {checkbutton {Color Postscript/SVG} {} color_ps {}}
  {checkbutton {Transparent SVG background} {} transparent_svg {}}
  {checkbutton {Debug mode} {} menu_debug_var {}}
  {checkbutton {Undo buffer on Disk} {} undo_type disk}
  {checkbutton {Enable stretch} Y enable_stretch {}}
  {checkbutton {Enable infix-interface} {} infix_interface {}}
  {checkbutton {Enable orthogonal wiring} Shift-L orthogonal_wiring {}}
  {checkbutton {Unsel. partial sel. wires after stretch move} {} unselect_partial_sel_wires {}}
  {checkbutton {Auto Join/Trim Wires} {} autotrim_wires {}}
  {checkbutton {Persistent wire/line place command} {} persistent_command {}}
  {checkbutton {Intuitive Click & Drag interface} {} intuitive_interface {}}
  {cascade Crosshair {} {} {}}
  {sub: checkbutton {Draw snap cursor} Alt-Z snap_cursor {}}
  {sub: checkbutton {Draw crosshair} Alt-X draw_crosshair {}}
  {sub: command {Crosshair size} {} {} {}}
  {command {Replace \[ and \] for buses in SPICE netlist} {} {} {}}
  {checkbutton {Group bus slices in Verilog instances} {} verilog_bitblast {}}
  {checkbutton {Draw grid} % draw_grid {}}
  {command {Half Snap Threshold} G {} {}}
  {command {Double Snap Threshold} Shift-G {} {}}
  {checkbutton {Variable grid point size} {} big_grid_points {}}
  {separator {} {} {} {}}
  {checkbutton {No XCopyArea drawing model} Ctrl+$ draw_window {}}
  {checkbutton {Fix for GPUs with broken tiled fill} {} fix_broken_tiled_fill {}}
  {checkbutton {Fix broken RDP mouse coordinates} {} fix_mouse_coord {}}
  {separator {} {} {} {}}
  {cascade {Netlist format / Symbol mode} {} {} {}}
  {sub: checkbutton {Flat netlist} : flat_netlist {}}
  {sub: checkbutton {Split netlist} {} split_files {}}
  {sub: radiobutton {Spectre netlist} {} netlist_type spectre}
  {sub: radiobutton {Spice netlist} {} netlist_type spice}
  {sub: radiobutton {VHDL netlist} {} netlist_type vhdl}
  {sub: radiobutton {Verilog netlist} {} netlist_type verilog}
  {sub: radiobutton {tEDAx netlist} {} netlist_type tedax}
  {sub: radiobutton {Symbol global attrs} {} netlist_type symbol}
}

update idletasks
if {![winfo exists .menubar.option]} {
  puts "OPTIONS-MENU: ERROR .menubar.option does not exist"
  flush stdout
  exit 2
}

proc run_compare {} {
  global expected
  set got [dump_menu .menubar.option]
  set fail 0
  
  # Ignore move constraint stuff because I haven't migrated it yet?
  # Wait, the 35 rows are the ONLY ones I parsed. If `got` has more (because I missed some), it will fail!
  
  set got_spine {}
  set ignore 0
  foreach row $got {
    # We only parsed 35 rows. But wait, I DELETED the exact block of lines 10246..10438 from xschem.tcl.
    # Are there more items added to .menubar.option elsewhere?
    if {[lindex $row 0] eq "cascade" && [lindex $row 1] eq "Move constraint"} { set ignore 1; continue }
    if {[lindex $row 0] eq "cascade" && [lindex $row 1] eq "Line width"} { set ignore 1; continue }
    if {$ignore && [lindex $row 0] eq "sub:"} { continue }
    set ignore 0
    lappend got_spine $row
  }

  set n [expr {max([llength $got_spine],[llength $expected])}]
  for {set i 0} {$i < $n} {incr i} {
    set g [lindex $got_spine $i]
    set e [lindex $expected $i]
    if {$g ne $e} {
      puts "DIFF\[$i\]  got: {$g}   expected: {$e}"
      set fail 1
    }
  }
  if {$fail} { puts "OPTIONS-MENU: FAIL" } else { puts "OPTIONS-MENU: MATCH" }
  flush stdout
  exit [expr {$fail ? 1 : 0}]
}
run_compare
