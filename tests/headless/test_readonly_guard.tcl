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
# REPO env override kept for the documented invocation; default derives from the
# script location so full_audit (which sets no REPO) doesn't die on line 1 with a
# blocking "can't read env(REPO)" popup.
if {![info exists env(REPO)]} {
  set env(REPO) [file normalize [file join [file dirname [info script]] .. ..]]
}
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

# edit_vi_prop reaches an external $editor exec if the readonly gate is absent
# (red-first / sabotage runs under X) — stub it inert: rcode {} = "unchanged".
proc edit_vi_prop {txtlabel} { set tctx::rcode {}; return {} }

# TREATMENT: read-only buffer refuses every mutating subcommand
xschem load $sch
xschem set readonly 1
set i0 [xschem get instances]; set w0 [xschem get wires]
check "treatment: buffer is read-only" [expr {[xschem get readonly] == 1}] ""
check "treatment: buffer starts unmodified" [expr {[xschem get modified] == 0}] ""

set cmds {
  copy_objects cut delete flip merge move_objects paste rotate
  add_graph add_image add_symbol_pin add_sch_pin add_wire_label arc change_elem_order instance line
  move_instance net_label place_symbol polygon rect reset_inst_prop text
  trim_wires wire undo redo align setprop replace_symbol apply_properties
  edit_vi_prop
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

# ISSUE 0266 ORDERING ROW. move_objects gained argument-shape validation (an unrecognised dispatch
# slot is now a TCL_ERROR naming the token). scheduler_readonly_reject must stay the FIRST thing
# the branch does, so a read-only buffer answers "read-only" for EVERY spelling -- including a bad
# one. The loop above only ever calls the verb bare (argc 2), which never reaches the new check, so
# it cannot see this. The read-only refusal is the more important thing to tell the user.
set rc [catch {xschem move_objects END} e]
check "treatment: 'move_objects END' refused as read-only" \
      [expr {$rc != 0 && [string match "*read-only*" $e]}] "(rc=$rc msg=[string range $e 0 60])"
check "treatment: read-only wins over the 0266 slot check" \
      [expr {![string match "*unrecognized argument*" $e]}] ""

# non-mutating query/nav commands must still work read-only (no over-block)
check "treatment: select_all works read-only" [expr {[catch {xschem select_all}] == 0}] ""
check "treatment: 'get' works read-only" [expr {[catch {xschem get instances}] == 0}] ""
check "treatment: 'translate' (query) works read-only" [expr {[catch {xschem translate -1 {x}}] == 0}] ""

if {$fail == 0} { puts "READONLY_GUARD_TEST_PASS" } else { puts "READONLY_GUARD_TEST_FAIL ($fail)" }
