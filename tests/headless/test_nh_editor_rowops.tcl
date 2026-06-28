# Net highlight style editor — per-row ops Move Up/Down, Delete, Duplicate (plan slice 7). GUI:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_rowops.tcl
# Ops act on the table row that holds field focus (an integer ::nhse_focus_row; the free row's "new"
# key disables them). They route through the fault-tolerant procs and renumber; focus follows the
# moved/duplicated row so ops chain. Driven directly (deterministic, no event injection).

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc cols {} { set out {} ; foreach r [net_hilight_style_current] { lappend out [lindex $r 1] } ; return $out }
proc reseed {} {
  set ::net_hilight_style {{0 red 1 {} 0 0 none 0} {1 green 1 {} 0 0 none 0} {2 blue 1 {} 0 0 none 0}}
  catch {xschem update_net_hilight_style}
  nhse_rebuild
}

set ::USER_CONF_DIR [file join [pwd] _nheops_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

set ::net_hilight_style {{0 red 1 {} 0 0 none 0} {1 green 1 {} 0 0 none 0} {2 blue 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

check "O1 ops bar present" [expr {[winfo exists .nhse.ops.up] && [winfo exists .nhse.ops.down] \
  && [winfo exists .nhse.ops.del] && [winfo exists .nhse.ops.dup]}] {}

# --- enable rule: table-row focus enables; first/last row grey Move Up/Down; free row disables ----
reseed ; nhse_focus_set 0
check "O2 Delete enabled on table-row focus" [expr {[.nhse.ops.del cget -state] eq {normal}}] "(=> [.nhse.ops.del cget -state])"
check "O2b Move Up disabled on row 0"        [expr {[.nhse.ops.up cget -state] eq {disabled}}] "(=> [.nhse.ops.up cget -state])"
check "O2c Move Down enabled on row 0"       [expr {[.nhse.ops.down cget -state] eq {normal}}] "(=> [.nhse.ops.down cget -state])"
nhse_focus_set 2
check "O2d Move Down disabled on last row"   [expr {[.nhse.ops.down cget -state] eq {disabled}}] "(=> [.nhse.ops.down cget -state])"
nhse_focus_set new
check "O3 ops disabled on free-row focus"    [expr {[.nhse.ops.del cget -state] eq {disabled} && [.nhse.ops.dup cget -state] eq {disabled}}] {}

# --- Move Down / Move Up swap with the neighbour; focus follows the moved row ----------------------
reseed ; nhse_focus_set 0 ; nhse_op_move 1
check "O4 move down swaps 0,1"        [expr {[cols] eq {green red blue}}] "(=> [cols])"
check "O5 focus follows moved row"    [expr {$::nhse_focus_row == 1}] "(=> $::nhse_focus_row)"
reseed ; nhse_focus_set 2 ; nhse_op_move -1
check "O6 move up swaps 1,2"          [expr {[cols] eq {red blue green}}] "(=> [cols])"
reseed ; nhse_focus_set 0 ; nhse_op_move -1
check "O7 move up on row 0 is no-op"  [expr {[cols] eq {red green blue}}] "(=> [cols])"

# --- Delete the focused row -----------------------------------------------------------------------
reseed ; nhse_focus_set 1 ; nhse_op_delete
check "O8 delete row 1"               [expr {[cols] eq {red blue}}] "(=> [cols])"

# --- Duplicate: copy immediately below the focused row; renumber; focus follows the clone ---------
reseed ; nhse_focus_set 0 ; nhse_op_duplicate
check "O9 duplicate row 0 below"      [expr {[cols] eq {red red green blue}}] "(=> [cols])"
check "O10 focus follows clone (i+1)" [expr {$::nhse_focus_row == 1}] "(=> $::nhse_focus_row)"

# --- the index==position invariant survives every op ----------------------------------------------
set idxok 1 ; set k 0 ; foreach r [net_hilight_style_current] { if {[lindex $r 0] != $k} { set idxok 0 } ; incr k }
check "O11 index==position after ops" $idxok "(=> [net_hilight_style_current])"

# --- ops chain: a second op acts on the row focus moved to --------------------------------------
reseed ; nhse_focus_set 0 ; nhse_op_move 1 ; nhse_op_move 1
check "O12 ops chain (red ends at row 2)" [expr {[cols] eq {green blue red}}] "(=> [cols])"

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
