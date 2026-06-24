proc dump_menu {w {indent ""}} {
  if {[catch {$w index end} end] || $end eq "none"} return
  for {set i 0} {$i <= $end} {incr i} {
    set type [$w type $i]
    if {$type eq "separator"} {
      puts "${indent}separator"
    } else {
      set label [$w entrycget $i -label]
      set accel ""
      catch {set accel [$w entrycget $i -accelerator]}
      puts "${indent}${type}: ${label} [expr {$accel ne \"\" ? \"($accel)\" : \"\"}]"
      if {$type eq "cascade"} {
        set sub [$w entrycget $i -menu]
        dump_menu $sub "$indent  "
      }
    }
  }
}
set menukey $env(MENUKEY)
dump_menu .menubar.$menukey
exit 0
