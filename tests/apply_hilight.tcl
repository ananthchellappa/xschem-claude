#
#  File: apply_hilight.tcl
#
#  Regression for apply_hilight: one-shot "apply a favourite highlight style".
#  See doc/claude/specs/apply_hilight.md
#
#  Run UNDER xschem:
#      cd tests
#      ../src/xschem --nogui --pipe -q --script apply_hilight.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils bus_resize.tcl]        ;# busresize::is_label_type
source [file join $utils apply_hilight.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}
# compare columns 1..7 of a parsed row (index col 0 is a placeholder)
proc cols17 {row} { return [lrange $row 1 7] }

# --- parser: the three accepted forms -------------------------------------
check {named = form} \
  [cols17 [aphl::parse {color="blue" pattern={10 20} thickness=10}]] {blue 10 {10 20} 0 0 none 0}
check {named dict form} \
  [cols17 [aphl::parse {color blue thickness 10 pattern {10 20}}]]   {blue 10 {10 20} 0 0 none 0}
check {positional form} \
  [cols17 [aphl::parse {4 purple 3 {20 20} 0 1200 none 0}]]          {purple 3 {20 20} 0 1200 none 0}
check {aliases width/dash/anim/speed} \
  [cols17 [aphl::parse {width 5 dash {2 2} anim march_fwd speed 3}]] {4 5 {2 2} 0 0 march_fwd 3}
check {omitted fields default} \
  [cols17 [aphl::parse {color blue}]]                                {blue 1 {} 0 0 none 0}
check {angle and blink named} \
  [cols17 [aphl::parse {color red angle 30 blink 1200}]]             {red 1 {} 30 1200 none 0}

# --- integration: noun-verb apply highlights the selected net -------------
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/lab_pin.sym 100 100 0 0 {name=l1 lab=clk}
xschem unselect_all ; xschem select instance l1
set before_rows [llength [net_hilight_style_current]]
apply_hilight {color green thickness 3 pattern {6 6}}
# the style got installed in the table
set found 0
foreach row [net_hilight_style_current] {
  if {[lrange [net_hilight_style_norm $row 0] 1 7] eq {green 3 {6 6} 0 0 none 0}} { set found 1 }
}
check "style installed in table" $found 1
# the net is now highlighted: re-select highlighted nets and expect a non-empty selection
xschem unselect_all
xschem select_hilight_net
check "selected net got highlighted" [expr {[xschem get lastsel] > 0}] 1

# --- a non-net selection alone is not 'noun' (sel_has_net = 0) ------------
xschem load [file normalize buried_hilight/a.sch]
xschem instance devices/res.sym 300 300 0 0 {name=R1}
xschem unselect_all ; xschem select instance R1
check "resistor alone is not a net selection" [aphl::sel_has_net] 0
xschem instance devices/lab_pin.sym 120 120 0 0 {name=l2 lab=d}
xschem select instance l2
check "label makes sel_has_net true" [aphl::sel_has_net] 1

if {$nfail} { puts "apply_hilight: $nfail check(s): FAIL" } \
else        { puts "apply_hilight: all checks PASS" }
