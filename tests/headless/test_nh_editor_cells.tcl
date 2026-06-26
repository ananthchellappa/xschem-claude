# Net highlight style editor — per-cell editing widgets (plan slice 4). GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_cells.tcl
# Drives the per-cell bound vars + commit path directly (deterministic, no event injection) and
# asserts: rgb.txt name parse, color/march/dash helpers, widget->table->widget round-trip with
# net_hilight_style_norm clamping, and the dash-empty disable rule.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc f0 {fld} { return [lindex [lindex $::net_hilight_style 0] $fld] }   ;# row 0, field fld

set ::USER_CONF_DIR [file join [pwd] _nhecells_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# --- pure helpers -------------------------------------------------------------
set names [nhse_rgb_names]
check "C1 rgb names incl red/orange/yellow" \
  [expr {[lsearch -exact $names red]>=0 && [lsearch -exact $names orange]>=0 && [lsearch -exact $names yellow]>=0}] "([llength $names] names)"
set nospace 1 ; foreach n $names { if {[string match "* *" $n]} { set nospace 0 ; break } }
check "C2 rgb names single-token" $nospace {}
check "C3 color_to_tk layer 4 = tctx color" [expr {[nhse_color_to_tk 4] eq [lindex $::tctx::colors 4]}] "(=> [nhse_color_to_tk 4])"
check "C4 color_to_tk red = red"            [expr {[nhse_color_to_tk red] eq {red}}] {}
check "C5 color_to_tk nonsense = {}"        [expr {[nhse_color_to_tk zzqqx] eq {}}] {}
check "C6 march raw->disp"  [expr {[nhse_march_to_disp march_fwd] eq {Forward} && [nhse_march_to_disp none] eq {Off}}] {}
check "C7 march disp->raw"  [expr {[nhse_march_to_raw Reverse] eq {march_rev} && [nhse_march_to_raw Off] eq {none}}] {}

# --- open with one known row, then edit via bound vars + commit ---------------
set ::net_hilight_style {{0 4 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks
check "C8 color combobox built" [winfo exists .nhse.tbl.sf.body.r0.c1.cb] {}
check "C8b width spinbox built" [winfo exists .nhse.tbl.sf.body.r0.c2] {}

# width clamp (0 -> 1) propagates to table AND re-syncs back into the widget var
set ::nhse_v(0,2) 0 ; nhse_commit
check "C9 width 0 clamped to 1 in table" [expr {[f0 2] == 1}] "(=> [f0 2])"
check "C10 width widget re-synced to 1"  [expr {$::nhse_v(0,2) == 1}] "(=> $::nhse_v(0,2))"

# color edit
set ::nhse_v(0,1) blue ; nhse_commit
check "C11 color edit -> table" [expr {[f0 1] eq {blue}}] "(=> [f0 1])"

# dash example fills the entry and the table, and enables angle/speed
set ::nhse_ex(0) Dash ; nhse_dash_apply_example 0
check "C12 dash example fills entry" [expr {$::nhse_v(0,3) eq {6 4}}] "(=> $::nhse_v(0,3))"
check "C13 dash in table"            [expr {[f0 3] eq {6 4}}] "(=> [f0 3])"
check "C14 angle+speed enabled with dash" \
  [expr {[.nhse.tbl.sf.body.r0.c4 cget -state] eq {normal} && [.nhse.tbl.sf.body.r0.c7 cget -state] eq {normal}}] \
  "(angle=[.nhse.tbl.sf.body.r0.c4 cget -state] speed=[.nhse.tbl.sf.body.r0.c7 cget -state])"

# marching: friendly -> raw in the table
set ::nhse_v(0,6) Forward ; nhse_commit
check "C15 march Forward -> march_fwd in table" [expr {[f0 6] eq {march_fwd}}] "(=> [f0 6])"

# clearing the dash disables angle/march/speed (solid pattern)
set ::nhse_v(0,3) {} ; nhse_dash_changed 0
check "C16 angle+speed disabled when solid" \
  [expr {[.nhse.tbl.sf.body.r0.c4 cget -state] eq {disabled} && [.nhse.tbl.sf.body.r0.c7 cget -state] eq {disabled}}] \
  "(angle=[.nhse.tbl.sf.body.r0.c4 cget -state] speed=[.nhse.tbl.sf.body.r0.c7 cget -state])"

# the angle slider's float value is coerced to an int (else norm would clamp it to 0)
set ::nhse_v(0,3) {4 4} ; nhse_dash_changed 0
set ::nhse_v(0,4) 30.0 ; nhse_commit
check "C17 angle 30.0 stored as int 30" [expr {[f0 4] == 30 && [f0 4] ne {30.0}}] "(=> [f0 4])"

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
