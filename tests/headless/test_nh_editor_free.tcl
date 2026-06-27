# Net highlight style editor — free-to-edit row + Add/Overwrite + Update + separator (plan slice 6).
# GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_free.tcl
# Composes a style in the pinned NEW row (bound to ::nhse_v(new,*)) and drives the Update path
# directly (deterministic, no event injection): Add appends, Overwrite(row#) replaces just that row,
# the free-row values persist after Update, and the action spinbox shows/hides with the action.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

set ::USER_CONF_DIR [file join [pwd] _nhefree_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# seed a 2-row table, open the editor
set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 3 1 {6 4} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

# --- structure: free row, NEW label, separator, action controls -------------------------------
check "S1 free row built"   [winfo exists .nhse.tbl.free.rnew.c1.cb] {}
check "S2 NEW label"        [expr {[.nhse.tbl.free.rnew.c0 cget -text] eq {NEW}}] "(=> [.nhse.tbl.free.rnew.c0 cget -text])"
check "S3 separator present" [winfo exists .nhse.tbl.sep] {}
check "S4 action combobox"  [winfo exists .nhse.tbl.free.act.action] {}
check "S5 Update button"    [winfo exists .nhse.tbl.free.act.update] {}

# the free row does NOT live in the scrollable table body (it is pinned)
check "S6 free row not in table body" [expr {![winfo exists .nhse.tbl.sf.body.rnew]}] {}

# --- compose a style in the free row (set the bound vars directly, like the slice-4 test) ------
set ::nhse_v(new,1) red
set ::nhse_v(new,2) 5
set ::nhse_v(new,3) {2 3}
set ::nhse_v(new,4) 10
set ::nhse_v(new,5) 250
set ::nhse_v(new,6) Forward
set ::nhse_v(new,7) 2

# --- Add: append the composed style as a new row at the end ------------------------------------
set ::nhse_action Add ; nhse_action_changed
nhse_free_update
set tab [net_hilight_style_current]
check "S7 Add appended a 3rd row" [expr {[llength $tab] == 3}] "(=> [llength $tab])"
set r2 [lindex $tab 2]
check "S8 appended row matches composed style" \
  [expr {[lindex $r2 1] eq {red} && [lindex $r2 2] == 5 && [lindex $r2 3] eq {2 3} \
      && [lindex $r2 4] == 10 && [lindex $r2 5] == 250 && [lindex $r2 6] eq {march_fwd} && [lindex $r2 7] == 2}] \
  "(=> $r2)"
check "S9 free-row values persist after Add" \
  [expr {$::nhse_v(new,1) eq {red} && $::nhse_v(new,3) eq {2 3} && $::nhse_v(new,6) eq {Forward}}] \
  "(=> [list $::nhse_v(new,1) $::nhse_v(new,3) $::nhse_v(new,6)])"

# --- Overwrite row #1 with the composed style; rows 0 and 2 untouched -------------------------
set ::nhse_action Overwrite ; nhse_action_changed
set ::nhse_over_idx 1
nhse_free_update
set tab [net_hilight_style_current]
check "S10 still 3 rows after overwrite" [expr {[llength $tab] == 3}] "(=> [llength $tab])"
set r1 [lindex $tab 1]
check "S11 row 1 overwritten by composed style" \
  [expr {[lindex $r1 1] eq {red} && [lindex $r1 3] eq {2 3} && [lindex $r1 6] eq {march_fwd}}] "(=> $r1)"
set r0 [lindex $tab 0]
check "S12 row 0 untouched" [expr {[lindex $r0 1] == 4 && [lindex $r0 3] eq {}}] "(=> $r0)"

# --- the row# spinbox is shown only for Overwrite (pack info errors when not managed) ----------
check "S13 row# spinbox shown for Overwrite" [expr {![catch {pack info .nhse.tbl.free.act.over}]}] {}
set ::nhse_action Add ; nhse_action_changed
update idletasks
check "S14 row# spinbox hidden for Add" [expr {[catch {pack info .nhse.tbl.free.act.over}]}] {}

# --- a free-row edit must NOT commit to the table; a table-row edit must (count real commits) ---
# (count nhse_commit invocations so the guard's behaviour is observable -- the free row is excluded
#  from nhse_assemble_table anyway, so a "table unchanged" check alone would pass either way.)
set ::nhse_commit_calls 0
rename nhse_commit nhse_commit_orig
proc nhse_commit {} { incr ::nhse_commit_calls ; nhse_commit_orig }
set c0 $::nhse_commit_calls
set ::nhse_v(new,2) 9 ; nhse_cell_commit new
check "S15 free-row cell edit does NOT commit" [expr {$::nhse_commit_calls == $c0}] "(calls +[expr {$::nhse_commit_calls - $c0}])"
set c1 $::nhse_commit_calls
set ::nhse_v(0,2) 7 ; nhse_cell_commit 0
check "S16 table-row cell edit DOES commit" [expr {$::nhse_commit_calls == $c1 + 1}] "(calls +[expr {$::nhse_commit_calls - $c1}])"
rename nhse_commit {} ; rename nhse_commit_orig nhse_commit

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
