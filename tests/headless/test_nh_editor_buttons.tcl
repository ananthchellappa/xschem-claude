# Net highlight style editor — OK / Apply / Save… / Cancel + snapshot-revert + located-save warning
# (plan slice 8). Two parts:
#  (1) LOGIC (runs headless): nhse_is_autoload_path + nhse_save_announce (the warn/echo branch fires
#      iff the Save path is NOT the auto-load file; the exact CIW load line is emitted).
#  (2) GUI (needs Tk/X): the button bar exists; an open-time snapshot is taken; Cancel/✕ revert the
#      live table to it; OK keeps the live state; Reset re-derives the default; WM-close == Cancel.
# Run headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_editor_buttons.tcl
# Run GUI:       DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_buttons.tcl

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc c0 {} { return [lindex [lindex [net_hilight_style_current] 0] 1] }   ;# row 0 color

set ::USER_CONF_DIR [file join [pwd] _nhebtn_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR
set auto [file join $::USER_CONF_DIR net_hilight_style]

# ---- (1) located-save path logic (no Tk needed) ----------------------------------------------
check "B1 autoload path recognized"  [nhse_is_autoload_path $auto] {}
check "B2 other path not autoload"   [expr {![nhse_is_autoload_path [file join $::USER_CONF_DIR somewhere_else]]}] {}

# capture ciw_echo output (it may not exist in --nogui, so stub conditionally)
set ::echoed {}
set had_echo [llength [info commands ciw_echo]]
if {$had_echo} { rename ciw_echo ciw_echo_orig }
proc ciw_echo {line {tag {}}} { lappend ::echoed $line }

check "B3 announce: autoload path does NOT warn" [expr {[nhse_save_announce $auto] == 0}] {}
check "B3b autoload echo mentions auto-load" [expr {[string match *automatically* [lindex $::echoed end]]}] "(=> [lindex $::echoed end])"
check "B4 announce: other path warns"        [expr {[nhse_save_announce /tmp/nh_demo_xyz] == 1}] {}
check "B4b other-path echo is the exact load command" \
  [expr {[lindex $::echoed end] eq {# to load these highlight styles next session: xschem --script {/tmp/nh_demo_xyz}}}] \
  "(=> [lindex $::echoed end])"

rename ciw_echo {}
if {$had_echo} { rename ciw_echo_orig ciw_echo }

# ---- (2) GUI: buttons, snapshot/revert, OK keeps, Reset, WM-close=Cancel ----------------------
if {[catch {winfo exists .}]} {
  file delete -force $::USER_CONF_DIR
  if {$fail == 0} { puts "RESULT: ALL PASS (logic only; GUI skipped — needs Tk/X)" } else { puts "RESULT: $fail FAILED" }
  flush stdout
  exit [expr {$fail == 0 ? 0 : 1}]
}

set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 3 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

check "B5 button bar present" [expr {[winfo exists .nhse.btns.ok] && [winfo exists .nhse.btns.apply] \
  && [winfo exists .nhse.btns.save] && [winfo exists .nhse.btns.cancel] && [winfo exists .nhse.btns.reset]}] {}
check "B6 snapshot captured on open" [expr {[info exists ::nhse_snapshot] && $::nhse_snapshot eq {{0 4 1 {} 0 0 none 0} {1 3 1 {} 0 0 none 0}}}] "(=> [expr {[info exists ::nhse_snapshot] ? $::nhse_snapshot : {<unset>}}])"
check "B7 WM-close bound to Cancel" [expr {[wm protocol .nhse WM_DELETE_WINDOW] eq {nhse_cancel}}] "(=> [wm protocol .nhse WM_DELETE_WINDOW])"

# a live edit applies immediately, then Cancel reverts it to the open-time snapshot
set ::nhse_v(0,1) red ; nhse_commit
check "B8 edit applied live (row 0 = red)" [expr {[c0] eq {red}}] "(=> [c0])"
nhse_cancel
check "B9 Cancel reverted row 0 to 4" [expr {[c0] == 4}] "(=> [c0])"
check "B10 Cancel closed the dialog"  [expr {![winfo exists .nhse]}] {}

# OK keeps the (already live) state and closes -- no revert
set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 3 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
net_hilight_style_editor ; update idletasks
set ::nhse_v(0,1) green ; nhse_commit
nhse_ok
check "B11 OK closed the dialog"        [expr {![winfo exists .nhse]}] {}
check "B12 OK kept the edit (green)"    [expr {[c0] eq {green}}] "(=> [c0])"

# Reset to defaults re-derives the layer default (replacing a custom table)
set ::net_hilight_style {{0 red 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
net_hilight_style_editor ; update idletasks
nhse_reset
check "B13 Reset replaced the custom row 0 (no longer red)" [expr {[c0] ne {red}}] "(=> [c0])"

# Save… path writes a re-sourceable conf with the table + seen flag (write proc, no dialog)
set tmp [file join $::USER_CONF_DIR saved_styles]
set ::net_hilight_style {{0 4 2 {6 4} 0 0 march_fwd 1}}
check "B14 write_net_hilight_style_conf succeeds" [expr {[write_net_hilight_style_conf $tmp] == 1}] {}
set ::net_hilight_style {} ; set ::net_hilight_editor_seen 0
source $tmp
check "B15 saved conf round-trips table" [expr {$::net_hilight_style eq {{0 4 2 {6 4} 0 0 march_fwd 1}}}] "(=> $::net_hilight_style)"
check "B16 saved conf sets seen flag"    [expr {$::net_hilight_editor_seen == 1}] {}

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
