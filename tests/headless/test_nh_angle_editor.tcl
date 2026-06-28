# Editor support for negative stripe-angles: the angle slider must span [-45,45] and the
# on-form preview must SHEAR (draw tilted polygons) for a negative angle, not fall back to a
# flat line. GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_angle_editor.tcl

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc count_type {c t} { set n 0; foreach id [$c find all] { if {[$c type $id] eq $t} { incr n } }; return $n }

set ::USER_CONF_DIR [file join [pwd] _nhangle_ed_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# open the editor on one thick, dashed row
set ::net_hilight_style {{0 4 14 {8 8} -30 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

# --- E1: the angle slider spans [-45, 45] -----------------------------------
set sc .nhse.tbl.sf.body.r0.c4
check "E1 angle slider -from is -45"  [expr {[$sc cget -from] == -45}] "(=> [$sc cget -from])"
check "E1b angle slider -to is 45"    [expr {[$sc cget -to]   == 45}]  "(=> [$sc cget -to])"

# --- E2: a NEGATIVE angle shears the preview (polygons), not flat lines ------
set ::nhse_focus_row 0
set ::nhse_v(0,4) -30 ; nhse_preview_paint
check "E2 negative angle -> sheared polygon preview" \
  [expr {[count_type .nhse.preview polygon] > 0}] "(polygons=[count_type .nhse.preview polygon])"

# --- E2b/E2c: positive still shears; angle 0 stays flat (regression) ---------
set ::nhse_v(0,4) 30 ; nhse_preview_paint
check "E2b positive angle -> sheared polygon preview" \
  [expr {[count_type .nhse.preview polygon] > 0}] "(polygons=[count_type .nhse.preview polygon])"
set ::nhse_v(0,4) 0 ; nhse_preview_paint
check "E2c angle 0 -> flat (no polygons)" \
  [expr {[count_type .nhse.preview polygon] == 0}] "(polygons=[count_type .nhse.preview polygon])"

catch {destroy .nhse}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
