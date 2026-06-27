# Net highlight style editor — STAGED commit model (user choice): field edits, row ops and the free-
# row Add/Overwrite only RESTAGE the table; nothing reaches the live session until Apply/OK (or a
# Cancel revert). GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_staged.tcl
# Counts pushes through nhse_apply_live (the single live-update chokepoint) to prove the deferral.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc c0 {} { return [lindex [lindex [net_hilight_style_current] 0] 1] }   ;# row 0 color

set ::USER_CONF_DIR [file join [pwd] _nhestg_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# Count ACTUAL C live-updates by wrapping the xschem command itself (the staged contract is exactly
# "no xschem update_net_hilight_style runs until Apply/OK"). Counting nhse_apply_live alone is hollow:
# a regression that staged with apply=1 would call the C update DIRECTLY, bypassing that chokepoint.
set ::upd 0
rename xschem xschem_real
proc xschem {args} {
  if {[lindex $args 0] eq {update_net_hilight_style}} { incr ::upd }
  return [eval [linsert $args 0 xschem_real]]
}

set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 3 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor ; update idletasks
set ::upd 0   ;# ignore anything during open

# a field edit RESTAGES the table but does NOT recompile/redraw the live session
set ::nhse_v(0,1) red ; nhse_commit
check "ST1 field edit does NOT update the live session" [expr {$::upd == 0}] "(updates=$::upd)"
check "ST2 field edit IS staged in the table" [expr {[c0] eq {red}}] "(=> [c0])"

# a row op restages, still no live update
nhse_focus_set 0 ; nhse_op_move 1
check "ST3 row op does NOT update the live session" [expr {$::upd == 0}] "(updates=$::upd)"

# free-row Add restages, still no live update
set ::nhse_v(new,1) blue ; set ::nhse_action Add ; nhse_action_changed ; nhse_free_update
check "ST4 free-row Add does NOT update the live session" [expr {$::upd == 0}] "(updates=$::upd)"

# Apply is the point where the staged table reaches the schematic
nhse_apply
check "ST5 Apply updates the live session" [expr {$::upd >= 1}] "(updates=$::upd)"

# OK flushes + updates + closes
set before $::upd
set ::nhse_v(0,2) 3 ; nhse_ok
check "ST6 OK updates the live session" [expr {$::upd > $before}] "(updates=$::upd)"
check "ST7 OK closed the dialog" [expr {![winfo exists .nhse]}] {}

rename xschem {} ; rename xschem_real xschem

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
