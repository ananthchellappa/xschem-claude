# Net highlight style editor — shared animated preview canvas (plan slice 5).
# Two parts:
#  (1) PURE TIMING MATH (runs headless too): nhse_dash_period + nhse_preview_state mirror the C
#      engine (net_hilight_compute_dash_period / net_hilight_style_on_now / net_hilight_march_offset)
#      so the preview animates exactly like a highlighted net, on the focused row's UNCOMMITTED edits.
#  (2) GUI (needs Tk/X): preview canvas exists, repaints on focus change, reflects uncommitted edits,
#      and the self-rescheduling after tick is cancelled on close (no orphan loop).
# Run headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_editor_preview.tcl
# Run GUI:       DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_preview.tcl

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
# evaluate an expr, FAIL (not abort) if the proc under test is missing / errors
proc safe {script} { if {[catch {uplevel 1 [list expr $script]} r]} { return 0 } else { return $r } }

# ---- (1) pure timing math (no Tk required) -----------------------------------

# dash period: sum of run lengths, DOUBLED for an odd run count; 0 for empty/all-zero.
check "P1 dash period {6 4} = 10"   [safe {[nhse_dash_period {6 4}] == 10}]   "(=> [catch {nhse_dash_period {6 4}} r; set r])"
check "P2 dash period {4 4 4} = 24" [safe {[nhse_dash_period {4 4 4}] == 24}] "(odd count doubled)"
check "P3 dash period {} = 0"       [safe {[nhse_dash_period {}] == 0}]       {}

# a raw 8-col row: {index color width dash angle blink_ms anim rate_persec}
proc vis {row now} { return [lindex [nhse_preview_state $row $now] 0] }
proc off {row now} { return [lindex [nhse_preview_state $row $now] 1] }

# solid + steady -> always visible, no march, at any time
set solid {0 4 1 {} 0 0 none 0}
check "P4 solid steady visible@0"    [safe {[vis {0 4 1 {} 0 0 none 0} 0] == 1}] {}
check "P5 solid steady visible@1234" [safe {[vis {0 4 1 {} 0 0 none 0} 1234] == 1}] {}
check "P6 solid steady offset 0"     [safe {[off {0 4 1 {} 0 0 none 0} 1234] == 0}] {}

# blink: 50% duty, ON for the first half of each period (blink_ms=1000 -> half=500)
check "P7 blink ON  @0"   [safe {[vis {0 4 1 {} 0 1000 none 0} 0]   == 1}] {}
check "P8 blink OFF @600" [safe {[vis {0 4 1 {} 0 1000 none 0} 600] == 0}] "(second half-period)"
check "P9 blink OFF @999" [safe {[vis {0 4 1 {} 0 1000 none 0} 999] == 0}] {}
check "P10 blink ON @1000" [safe {[vis {0 4 1 {} 0 1000 none 0} 1000] == 1}] "(next period)"

# marching fwd: dash {6 4} P=10, rate 1 -> offset = P*frac(rate*now_s), advances with time, wraps at 1s
check "P11 march fwd offset 0 @0"      [safe {abs([off {0 4 1 {6 4} 0 0 march_fwd 1} 0]) < 1e-9}] {}
check "P12 march fwd advances @250"    [safe {[off {0 4 1 {6 4} 0 0 march_fwd 1} 250] > [off {0 4 1 {6 4} 0 0 march_fwd 1} 0]}] {}
check "P13 march fwd advances @500"    [safe {[off {0 4 1 {6 4} 0 0 march_fwd 1} 500] > [off {0 4 1 {6 4} 0 0 march_fwd 1} 250]}] {}
check "P14 march fwd @250 = 2.5"       [safe {abs([off {0 4 1 {6 4} 0 0 march_fwd 1} 250] - 2.5) < 1e-9}] "(P*0.25)"
check "P15 march fwd wraps @1000 -> 0" [safe {abs([off {0 4 1 {6 4} 0 0 march_fwd 1} 1000]) < 1e-9}] {}

# marching rev: mirror -> offset = P - fwd
check "P16 march rev @250 = 7.5 (P-fwd)" [safe {abs([off {0 4 1 {6 4} 0 0 march_rev 1} 250] - 7.5) < 1e-9}] {}
check "P17 march rev != fwd @250"        [safe {[off {0 4 1 {6 4} 0 0 march_rev 1} 250] != [off {0 4 1 {6 4} 0 0 march_fwd 1} 250]}] {}

# a marching style with NO dash (nothing to scroll) or rate 0 does not march (matches the engine)
check "P18 march no-dash -> offset 0" [safe {[off {0 4 1 {} 0 0 march_fwd 1} 250] == 0}] {}
check "P19 march rate 0  -> offset 0" [safe {[off {0 4 1 {6 4} 0 0 march_fwd 0} 250] == 0}] {}

# blink + march compose: still both gated independently (off in second half, marching value present)
check "P20 blink+march OFF@600 but marches" \
  [safe {[vis {0 4 1 {6 4} 0 1000 march_fwd 1} 600] == 0 && [off {0 4 1 {6 4} 0 1000 march_fwd 1} 250] > 0}] {}

# ---- (2) GUI: canvas exists, repaints on focus, reflects edits, tick cancels on close ----
if {[catch {winfo exists .}]} {
  if {$fail == 0} { puts "RESULT: ALL PASS (math only; GUI skipped — needs Tk/X)" } else { puts "RESULT: $fail FAILED" }
  flush stdout
  exit [expr {$fail == 0 ? 0 : 1}]
}

set ::USER_CONF_DIR [file join [pwd] _nheprev_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# two rows so we can test focus tracking; row 0 solid red (non-blinking -> always visible)
set ::net_hilight_style {{0 red 2 {} 0 0 none 0} {1 3 1 {6 4} 0 0 march_fwd 1}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

check "G1 preview canvas exists" [winfo exists .nhse.preview] {}
check "G2 default focus row 0"   [expr {$::nhse_focus_row == 0}] "(=> $::nhse_focus_row)"

# row 0 is solid red & non-blinking -> the highlight line is painted in red
nhse_preview_paint
set fills {} ; foreach it [.nhse.preview find all] { lappend fills [.nhse.preview itemcget $it -fill] }
check "G3 preview reflects row-0 color (red)" [expr {[lsearch -exact $fills red] >= 0}] "(fills=$fills)"

# focus change repaints from the newly focused row's UNCOMMITTED widget value
set ::nhse_v(1,1) green
nhse_focus_set 1
check "G4 focus follows to row 1" [expr {$::nhse_focus_row == 1}] {}
set fills {} ; foreach it [.nhse.preview find all] { lappend fills [.nhse.preview itemcget $it -fill] }
check "G5 preview reflects row-1 uncommitted color (green)" [expr {[lsearch -exact $fills green] >= 0}] "(fills=$fills)"

# the animation tick is scheduled while open ...
check "G6 preview tick scheduled while open" [info exists ::nhse_preview_after] {}

# ... and cancelled (no orphan after) once the dialog is destroyed
destroy .nhse
update
check "G7 preview tick cancelled on close" [expr {![info exists ::nhse_preview_after]}] {}

file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
