# devices/vpulse — a PULSE voltage source. Static field set, so it only RELABELS
# the generic Edit-Properties fields (no custom widget). Covers field_labels, the
# netlist (DC + PULSE), and the slickprop::build_fields integration (friendly
# labels, every param a plain entry, no custom widget).
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_vpulse.tcl
set fail 0; set npass 0
proc check {name got exp} { global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail } }
proc check_true {name c} { check $name [expr {$c ? 1 : 0}] 1 }
proc check_match {name got pat} { global fail npass
  if {[regexp -- $pat $got]} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} !~ /$pat/"; incr fail } }
proc symattr {sym tok} { set r {}; catch {set r [string trim [xschem getprop symbol $sym $tok]]}; return $r }
proc find_cls {w cls} { if {[winfo class $w] eq $cls} {return $w}
  foreach c [winfo children $w] { set r [find_cls $c $cls]; if {$r ne {}} {return $r} }; return {} }

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set symdir  [file join $repo xschem_libs_newsym devices vpulse symbol]
set symsym  [file join $symdir vpulse.sym]
set symtcl  [file join $symdir vpulse.tcl]
set scratch [file normalize [file join [pwd] _vpulse_[pid]]]
file delete -force $scratch; file mkdir $scratch

source $symtcl
check "field_labels: Vpulse"  [dict get [vpulse::field_labels] Vpulse] {Pulsed Value (V2)}
check "field_labels: PER"     [dict get [vpulse::field_labels] PER]    {Period (PER)}
check_true "no field_custom (static)" [expr {[info commands ::vpulse::field_custom] eq {}}]

catch {xschem load_symbol $symsym}
check "symbol edit_form ns"   [symattr $symsym edit_form] vpulse
check "symbol netlist format" [symattr $symsym format] \
  {@name @pinlist @DC PULSE(@Vinit @Vpulse @TD @TR @TF @PW @PER )}

# netlist: DC + PULSE(V1 V2 TD TR TF PW PER)
set sch [file join $scratch tb.sch]
set f [open $sch w]
puts $f "v {xschem version=3.4.8RC file_version=1.2}"
puts $f "G {}"; puts $f "V {}"; puts $f "S {}"; puts $f "E {}"
puts $f "C \{$symsym\} 100 100 0 0 \{name=V1 DC=0.2 Vinit=0 Vpulse=1.8 TD=5n TR=1n TF=1n PW=20n PER=50n\}"
close $f
set ::netlist_dir $scratch
catch {xschem set netlist_type spice}
xschem load $sch
xschem netlist
set nl [read [set fp [open [file join $scratch tb.spice] r]]][close $fp]
check_match "netlist V line DC + PULSE" $nl {(?i)V1 \S+ \S+ 0\.2 PULSE\(0 1\.8 5n 1n 1n 20n 50n ?\)}

# generic-form integration: friendly labels, all plain entries, no custom widget
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  set ::symbol $symsym
  catch {destroy .tf}
  frame .tf
  slickprop::build_fields .tf {name=V1 DC=0.2 Vinit=0 Vpulse=1.8 TD=5n TR=1n TF=1n PW=20n PER=50n} \
                              {name=V1 DC=0 Vinit=0 Vpulse=1 TD=0 TR=1n TF=1n PW=50n PER=100n}
  set gotlabels {}
  foreach w [winfo children .tf] { catch { if {[winfo class $w] eq "Label"} { lappend gotlabels [$w cget -text] } } }
  check_true "friendly label 'Pulsed Value (V2)'" [expr {[lsearch -exact $gotlabels {Pulsed Value (V2)}] >= 0}]
  check_true "friendly label 'Delay Time (TD)'"   [expr {[lsearch -exact $gotlabels {Delay Time (TD)}] >= 0}]
  check_true "no custom widget (no spinbox)"       [expr {[find_cls .tf Spinbox] eq {}}]
  check_true "Vpulse is a plain entry"             [expr {$::slickprop::cur(entry,Vpulse) ne {}}]
  check "field_value(Vpulse) reads the entry"      [slickprop::field_value Vpulse] 1.8
  catch {destroy .tf}
} else { puts "build_fields GUI legs skipped (no DISPLAY)" }

file delete -force $scratch
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
