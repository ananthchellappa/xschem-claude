# test_menu_widgets.tcl — verifies all migrated menus exist and have entries
set fail 0; set pass 0
proc chk {name widget} {
  global fail pass
  if {![winfo exists $widget]} {
    puts "FAIL: $name missing ($widget)"; incr fail; return
  }
  set n [$widget index end]
  if {$n eq "none"} {
    puts "FAIL: $name empty ($widget)"; incr fail; return
  }
  # print first entry
  catch { set lbl [$widget entrycget 0 -label] } lbl
  puts "PASS: $name OK ([expr {$n+1}] entries, first=\'$lbl\')"
  incr pass
}
after 300 {
  chk File       .menubar.file.m
  chk Edit       .menubar.edit.m
  chk View       .menubar.view.m
  chk Options    .menubar.option.m
  chk Properties .menubar.prop.m
  chk Tools      .menubar.tools.m
  chk Symbol     .menubar.sym.m
  chk Highlight  .menubar.hilight.m
  chk Simulation .menubar.simulation.m
  chk Waves      .menubar.waves.m
  chk Help       .menubar.help.m
  # Options must not start with a layer
  catch {
    set f [.menubar.option.m entrycget 0 -label]
    if {[string match -nocase "*layer*" $f]} {
      puts "FAIL: Options first entry is a layer: $f"; incr ::fail
    } else {
      puts "PASS: Options first entry OK: $f"; incr ::pass
    }
  }
  puts ""
  puts "RESULT: $pass passed, $fail failed"
  exit [expr {$fail > 0 ? 1 : 0}]
}
