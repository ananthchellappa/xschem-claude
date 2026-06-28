# Net highlight style editor — user feedback round 2. GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_flush_scroll.tcl
#  (1) Apply/OK/Save/row-ops FLUSH a typed-but-not-focused-out field edit (point 1: a value you typed
#      without tabbing out was lost when clicking Apply, because it lived only in the widget).
#  (2) The table scrolls on a mouse wheel anywhere over it (point 3), except over a combobox dropdown.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc s7 {} { return [lindex [lindex [net_hilight_style_current] 0] 7] }   ;# row 0 speed

set ::USER_CONF_DIR [file join [pwd] _nhefs_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# --- (1) flush on Apply / OK / row-op ----------------------------------------------------------
set ::net_hilight_style {{0 4 1 {6 4} 0 0 march_fwd 2}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor ; update idletasks

# a Tk entry's -textvariable updates ::nhse_v live as you type, but no <FocusOut>/<Return> has fired,
# so the table still holds the old value -- this is exactly the "typed but not committed" state.
set ::nhse_v(0,7) 9
check "F1 typed value not yet in the table" [expr {[s7] == 2}] "(=> [s7])"
nhse_apply
check "F2 Apply flushes the typed edit"     [expr {[s7] == 9}] "(=> [s7])"

set ::nhse_v(0,7) 5
nhse_ok
check "F3 OK flushes the typed edit" [expr {[s7] == 5}] "(=> [s7])"
check "F4 OK closed the dialog"      [expr {![winfo exists .nhse]}] {}

# a row op should also act on the in-progress edit, not the last focus-out value
set ::net_hilight_style {{0 4 1 {6 4} 0 0 march_fwd 2} {1 3 1 {6 4} 0 0 march_fwd 2}}
catch {xschem update_net_hilight_style}
net_hilight_style_editor ; update idletasks
nhse_focus_set 0
set ::nhse_v(0,7) 7
nhse_op_move 1
# row that was 0 (now moved to position 1) carries the flushed speed 7
check "F5 row op flushes the typed edit" [expr {[lindex [lindex [net_hilight_style_current] 1] 7] == 7}] \
  "(=> [net_hilight_style_current])"
catch {destroy .nhse}

# --- (2) mouse-wheel scrolling over the table --------------------------------------------------
set rows {} ; for {set i 0} {$i < 20} {incr i} { lappend rows [list $i 4 1 {} 0 0 none 0] }
set ::net_hilight_style $rows
catch {xschem update_net_hilight_style}
net_hilight_style_editor ; update idletasks

check "W1 wheel bound on a row cell (not just the scrollbar)" [expr {[bind .nhse.tbl.sf.body.r0.c0 <Button-4>] ne {}}] {}
check "W2 wheel NOT bound on a combobox (dropdown keeps its own scroll)" [expr {[bind .nhse.tbl.sf.body.r0.c1.cb <Button-4>] eq {}}] {}
# force a known scrollable state (a headless toplevel may auto-size tall enough to show every row)
.nhse.tbl.sf configure -scrollregion {0 0 200 5000}
update idletasks
set y0 [lindex [.nhse.tbl.sf yview] 0]
nhse_wheel 5
update idletasks
set y1 [lindex [.nhse.tbl.sf yview] 0]
check "W3 wheel scroll advances the view" [expr {$y1 > $y0}] "(y0=$y0 y1=$y1)"
nhse_wheel -5
update idletasks
check "W4 wheel scroll back returns toward top" [expr {[lindex [.nhse.tbl.sf yview] 0] < $y1}] {}

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
