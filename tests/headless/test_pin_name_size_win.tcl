# P9 `xschem get pin_name_size <inst> <pin> ?<win>?` -- the optional window-path arg.
#
# Reproduces the user-reported multi-window gotcha: every `xschem` command binds to the
# CURRENT window's context (the global xctx). With a schematic front, the query works; open
# a SECOND window (a different context, here an empty schematic with 0 instances) and it
# becomes current, so a plain `get pin_name_size <i> 0` -- and the `[xschem get instances]-1`
# people compose it with -- now reads the wrong context and fails "instance index out of
# range". The optional <win> arg borrows the addressed window's context for the one command
# (net_hilight_borrow_ctx), fixing the query without changing focus.
#
# RED (no <win>): with the empty window front, `get pin_name_size 0 0` errors.
# GREEN (<win>):  `get pin_name_size 0 0 <schematic_win>` returns the pin's size regardless.
#
# Needs X (real windows). Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_pin_name_size_win.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
set wd   [file join $here pin_name_size_win_work]
file delete -force $wd; file mkdir $wd

# a symbol whose one pin OWNS its name at a known size (0.42)
set sym $wd/eye.sym
set fp [open $sym w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nK {type=subcircuit}\nV {}\nS {}\nE {}"
puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in show_pinname=true name_dx=8 name_dy=-3 name_size=0.42}"
close $fp

# an EMPTY schematic (0 instances) to open as the second, front window
set esch $wd/empty.sch
set fp [open $esch w]
puts $fp "v {xschem version=3.4.8RC file_version=1.3}"
puts $fp "G {}\nV {}\nS {}\nE {}"
close $fp

set ::tabbed_interface 1
catch {xschem new_schematic destroy_all {}}

# main window .drw: a schematic holding one instance of the owned-pin symbol
xschem clear force
xschem instance $sym 0 0 0 0 {name=x1}
set i [expr {[xschem get instances]-1}]
set schwin [xschem get current_win_path]
update idletasks
check "S0 schematic is front" [expr {$schwin eq {.drw}}] "(cur=$schwin)"
check "S0 plain query works while schematic front" \
  [expr {[xschem get pin_name_size $i 0] eq {0.42}}] "(got [xschem get pin_name_size $i 0])"

# open a SECOND real window on the empty schematic and switch to it -> now front
xschem new_schematic create_window .x1 $esch
xschem new_schematic switch .x1.drw
update idletasks
check "S1 empty window is now front" \
  [expr {[xschem get current_win_path] eq {.x1.drw}}] "(cur=[xschem get current_win_path])"
check "S1 front window has 0 instances" [expr {[xschem get instances] == 0}] \
  "(inst=[xschem get instances])"

# RED: plain query now reads the FRONT (empty) context -> out of range (the reported bug)
check "S2 plain query errors while empty window front (reproduces bug)" \
  [catch {xschem get pin_name_size $i 0}] "(this is the wrong-window failure)"

# GREEN: address the schematic by path -> borrows its context, returns the pin size
set got ""
set rc [catch {xschem get pin_name_size $i 0 $schwin} got]
check "S3 <win>-addressed query returns the pin size across windows" \
  [expr {$rc == 0 && $got eq {0.42}}] "(rc=$rc got=$got)"

# borrow/restore is balanced: focus and the front context are unchanged afterward
check "S4 current window unchanged after borrow" \
  [expr {[xschem get current_win_path] eq {.x1.drw}}] "(cur=[xschem get current_win_path])"
check "S4 front context still 0 instances after borrow" \
  [expr {[xschem get instances] == 0}] "(inst=[xschem get instances])"

# an explicit but unknown window path errors (does NOT silently use the front window)
check "S5 unknown window path errors" [catch {xschem get pin_name_size $i 0 .bogus.drw}] "(want error)"

catch {xschem new_schematic destroy_all {}}
file delete -force $wd
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
