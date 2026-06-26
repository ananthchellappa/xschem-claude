# Net highlight style editor — read-only table view (plan slice 3). GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_table.tcl
# Seeds a known 3-row table, opens the editor, and asserts one row per style is rendered with the
# right per-field cell values + a header; then asserts an external table change re-renders on reopen.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc celltext {w} { if {[catch {$w cget -text} t]} { return <none> } ; return $t }
proc nrows {body} {
  set n 0
  if {[winfo exists $body]} {
    foreach c [winfo children $body] { if {[regexp {\.r[0-9]+$} $c]} { incr n } }
  }
  return $n
}

# Isolate from the real ~/.xschem: opening the editor auto-writes the seen marker, so point
# USER_CONF_DIR at a throwaway dir (cleaned up at the end).
set ::USER_CONF_DIR [file join [pwd] _nhetable_[pid]]
file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

set body .nhse.tbl.sf.body

# --- a known 3-row table ------------------------------------------------------
set ::net_hilight_style {{0 4 1 {} 0 0 none 0} {1 red 3 {6 4} 30 0 march_fwd 2} {2 #00ff00 2 {} 0 250 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks

check "T1 scrollable body built"  [winfo exists $body]            "(=> [winfo exists $body])"
check "T2 one row per style (3)"  [expr {[nrows $body] == 3}]     "(=> [nrows $body])"
check "T3 row0 idx col = 0"        [expr {[celltext $body.r0.c0] eq {0}}]        "(=> [celltext $body.r0.c0])"
check "T4 row0 color col = 4"      [expr {[celltext $body.r0.c1] eq {4}}]        "(=> [celltext $body.r0.c1])"
check "T5 row1 color = red"        [expr {[celltext $body.r1.c1] eq {red}}]      "(=> [celltext $body.r1.c1])"
check "T6 row1 pattern = '6 4'"    [expr {[celltext $body.r1.c3] eq {6 4}}]      "(=> [celltext $body.r1.c3])"
check "T7 row1 march = march_fwd"  [expr {[celltext $body.r1.c6] eq {march_fwd}}] "(=> [celltext $body.r1.c6])"
check "T8 row2 color = #00ff00"    [expr {[celltext $body.r2.c1] eq {#00ff00}}]  "(=> [celltext $body.r2.c1])"
check "T9 row2 blink = 250"        [expr {[celltext $body.r2.c5] eq {250}}]      "(=> [celltext $body.r2.c5])"
check "T10 header row has Color"   [string match -nocase *color* [celltext .nhse.tbl.head.c1]] "(=> [celltext .nhse.tbl.head.c1])"

# --- external change -> reopen re-renders -------------------------------------
set ::net_hilight_style {{0 1 1 {} 0 0 none 0}}
catch {xschem update_net_hilight_style}
net_hilight_style_editor
update idletasks
check "T11 reopen reflects external change (1 row)" [expr {[nrows $body] == 1}] "(=> [nrows $body])"

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
