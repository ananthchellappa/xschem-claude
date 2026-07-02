# Regression for issue 0041: every mutating `xschem` subcommand must be refused on a
# read-only buffer via the Tcl command surface (scripts, the persistent/TCP command
# server, action-log replay), leaving the buffer unmodified; non-mutating query/nav
# commands must still work (no over-block). Control-vs-treatment so a green run can't
# be hollow: first prove the ops DO mutate a writable buffer, then prove read-only
# blocks the identical ops.
#
# Run headless:
#   REPO=<repo> src/xschem --nogui --rcfile tests/headless/minrc --pipe -q \
#       --nolog --script tests/headless/test_readonly_guard.tcl
set sch $env(REPO)/xschem_library/examples/Q1.sch
set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# CONTROL A: writable buffer, delete mutates
xschem load $sch
set i0 [xschem get instances]
xschem select_all
set rc [catch {xschem delete} e]
check "control: delete mutates writable" [expr {$rc == 0 && [xschem get instances] < $i0}] "($i0 -> [xschem get instances])"

# CONTROL B: writable buffer, wire creation mutates
xschem load $sch
set w0 [xschem get wires]
set rc [catch {xschem wire 10 10 200 10} e]
check "control: wire creation mutates writable" [expr {$rc == 0 && [xschem get wires] > $w0}] "($w0 -> [xschem get wires])"

# TREATMENT: read-only buffer refuses every mutating subcommand
xschem load $sch
xschem set readonly 1
set i0 [xschem get instances]; set w0 [xschem get wires]
check "treatment: buffer is read-only" [expr {[xschem get readonly] == 1}] ""
check "treatment: buffer starts unmodified" [expr {[xschem get modified] == 0}] ""

set cmds {
  copy_objects cut delete flip merge move_objects paste rotate
  add_graph add_image add_symbol_pin arc change_elem_order instance line
  move_instance net_label place_symbol polygon rect reset_inst_prop text
  trim_wires wire undo redo align setprop replace_symbol
}
set refused 0
foreach cmd $cmds {
  xschem select_all
  set rc [catch {xschem $cmd} e]
  if {$rc != 0 && [string match "*read-only*" $e]} {
    incr refused
  } else {
    check "treatment: '$cmd' refused" 0 "(rc=$rc msg=[string range $e 0 50])"
  }
}
check "treatment: all mutating subcommands refused" [expr {$refused == [llength $cmds]}] "($refused/[llength $cmds])"
check "treatment: instance count unchanged" [expr {[xschem get instances] == $i0}] "($i0)"
check "treatment: wire count unchanged" [expr {[xschem get wires] == $w0}] "($w0)"
check "treatment: buffer still unmodified" [expr {[xschem get modified] == 0}] ""

# non-mutating query/nav commands must still work read-only (no over-block)
check "treatment: select_all works read-only" [expr {[catch {xschem select_all}] == 0}] ""
check "treatment: 'get' works read-only" [expr {[catch {xschem get instances}] == 0}] ""
check "treatment: 'translate' (query) works read-only" [expr {[catch {xschem translate -1 {x}}] == 0}] ""

if {$fail == 0} { puts "READONLY_GUARD_TEST_PASS" } else { puts "READONLY_GUARD_TEST_FAIL ($fail)" }
