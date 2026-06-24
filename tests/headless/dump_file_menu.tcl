# Introspect the generated File menu and compare against the known-good original
# structure (label/type/accelerator per entry, including submenus). Run under a
# real X display so build_widgets has created the menu widgets.
#
#   DISPLAY=:0 ./src/xschem --script tests/headless/dump_file_menu.tcl

proc dump_menu {w} {
  set out {}
  set last [$w index end]
  if {$last eq {none} || $last eq {}} { return $out }
  for {set i 0} {$i <= $last} {incr i} {
    set type [$w type $i]
    if {$type eq {separator}} {
      lappend out [list separator {} {}]
      continue
    }
    set label [$w entrycget $i -label]
    set accel [$w entrycget $i -accelerator]
    lappend out [list $type $label $accel]
    if {$type eq {cascade}} {
      set sub [$w entrycget $i -menu]
      foreach child [dump_menu $sub] {
        lappend out [concat sub: $child]
      }
    }
  }
  return $out
}

# (type label accelerator) expected for .menubar.file, in order, with submenu
# children flattened and tagged "sub:".  Derived from the pre-refactor xschem.tcl.
set expected {
  {command {Clear Schematic} Ctrl+N}
  {command {Clear Symbol} Ctrl+Shift+N}
  {command {Component browser} {Shift-Ins, Ctrl-I}}
  {command Open Ctrl+O}
  {command {Open in new window} Alt+O}
  {command {Open last closed} Ctrl+Shift+T}
  {command {Open most recent} Ctrl+Shift+O}
  {cascade {Open recent} {}}
  {command {Create new window/tab} Ctrl+T}
  {command {Open selected schematic in new window} Alt+E}
  {command {Open selected symbol in new window} Alt+I}
  {command {Delete files} Shift-D}
  {command Save Ctrl+S}
  {command Merge B}
  {command Reload Alt+S}
  {command {Save as} Ctrl+Shift+S}
  {command {Save as symbol} Ctrl+Alt+S}
  {cascade {Image export} {}}
  {sub: command {EPS Selection Export} {}}
  {sub: command {PDF/PS Export} *}
  {sub: command {PDF/PS Export Full} {}}
  {sub: command {Hierarchical PDF/PS Export} {}}
  {sub: command {PNG Export} Ctrl+*}
  {sub: command {SVG Export} Alt+*}
  {separator {} {}}
  {command {Start new Xschem process} X}
  {command {Close schematic} Ctrl+W}
  {command {Quit Xschem} Ctrl+Q}
}

update idletasks
if {![winfo exists .menubar.file]} {
  puts "FILE-MENU: ERROR .menubar.file does not exist"
  flush stdout
  exit 2
}
proc run_compare {} {
  global expected
  set got [dump_menu .menubar.file]
  # The dynamic "Open recent" submenu content is runtime/state dependent, so we
  # only compare the File-menu spine (drop any sub: rows under Open recent, which
  # appear right after its cascade entry and before Create new window/tab).
  set got_spine {}
  set in_recent 0
  foreach row $got {
    if {[lindex $row 0] eq {cascade} && [lindex $row 1] eq {Open recent}} {
      lappend got_spine $row; set in_recent 1; continue
    }
    if {$in_recent} {
      if {[lindex $row 0] eq {sub:}} { continue } else { set in_recent 0 }
    }
    lappend got_spine $row
  }
  puts "MENU-ENTRIES: [llength $got_spine] (expected [llength $expected])"
  set fail 0
  set n [expr {max([llength $got_spine],[llength $expected])}]
  for {set i 0} {$i < $n} {incr i} {
    set g [lindex $got_spine $i]
    set e [lindex $expected $i]
    if {$g ne $e} {
      puts "DIFF\[$i\]  got: {$g}   expected: {$e}"
      set fail 1
    }
  }
  if {$fail} { puts "FILE-MENU: FAIL" } else { puts "FILE-MENU: MATCH" }
  flush stdout
  exit [expr {$fail ? 1 : 0}]
}
run_compare
