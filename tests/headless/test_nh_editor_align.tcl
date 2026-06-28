# Net highlight style editor — header/column alignment (user feedback). GUI (needs Tk/X):
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_align.tcl
# The header labels must sit directly over their body columns. With grid + shared per-column widths,
# each header cell's left screen-x equals the corresponding cell's left screen-x in the free row and
# in every table row.

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; run with DISPLAY set, no --nogui)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

set ::USER_CONF_DIR [file join [pwd] _nhealign_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

set ::net_hilight_style {{0 4 1 {6 4} 0 0 none 0} {1 17 2 {} 0 0 none 0} {2 red 1 {2 3} 0 0 none 0}}
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor
update idletasks
update idletasks   ;# let the two-pass column sizing settle

set tol 3
# header cell vs body row-0 cell, and vs the free row, must share a left edge per column
for {set c 0} {$c < 8} {incr c} {
  set h .nhse.tbl.head.c$c
  set b .nhse.tbl.sf.body.r0.c$c
  set fr .nhse.tbl.free.rnew.c$c
  if {![winfo exists $h] || ![winfo exists $b]} { check "A$c header/body cell exists" 0 "($h $b)" ; continue }
  set dx [expr {abs([winfo rootx $h] - [winfo rootx $b])}]
  check "A$c header aligns over body column $c" [expr {$dx <= $tol}] "(dx=$dx px)"
  if {[winfo exists $fr]} {
    set dxf [expr {abs([winfo rootx $h] - [winfo rootx $fr])}]
    check "A${c}f header aligns over free-row column $c" [expr {$dxf <= $tol}] "(dx=$dxf px)"
  }
}

# two table rows must align with each other too (sanity that all rows share the grid)
for {set c 1} {$c < 8} {incr c} {
  set r0 .nhse.tbl.sf.body.r0.c$c
  set r2 .nhse.tbl.sf.body.r2.c$c
  if {[winfo exists $r0] && [winfo exists $r2]} {
    set dx [expr {abs([winfo rootx $r0] - [winfo rootx $r2])}]
    check "B$c rows share column $c" [expr {$dx <= $tol}] "(dx=$dx px)"
  }
}

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
