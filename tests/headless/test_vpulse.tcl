# devices/vpulse custom cell — netlist format (DC + PULSE), the cell-declared
# custom-form hook, and the static form (seed / apply).
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_vpulse.tcl
set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail }
}
proc check_true {name c} { check $name [expr {$c ? 1 : 0}] 1 }
proc check_match {name got pat} {
  global fail npass
  if {[regexp -- $pat $got]} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} !~ /$pat/"; incr fail }
}

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
set symdir  [file join $repo xschem_libs_newsym devices vpulse symbol]
set symsym  [file join $symdir vpulse.sym]
set symtcl  [file join $symdir vpulse.tcl]
set scratch [file normalize [file join [pwd] _vpulse_[pid]]]
file delete -force $scratch; file mkdir $scratch

# --- pure: field table (source the companion tcl directly) ------------------
source $symtcl
check "8 fields (DC + 7 PULSE params)" [expr {[llength [vpulse::fields]] / 2}] 8
check "first field is DC"              [lindex [vpulse::fields] 0] DC
check "PULSE order Vinit..PER" \
  [lmap {t l} [vpulse::fields] {set t}] {DC Vinit Vpulse TD TR TF PW PER}

# --- symbol declares custom form + netlist format ---------------------------
proc symattr {sym tok} { set r {}; catch {set r [string trim [xschem getprop symbol $sym $tok]]}; return $r }
catch {xschem load_symbol $symsym}
check "symbol edit_form attr" [symattr $symsym edit_form] vpulse::edit_form
check "symbol netlist format" [symattr $symsym format] \
  {@name @pinlist @DC PULSE(@Vinit @Vpulse @TD @TR @TF @PW @PER )}
check_true "companion tcl readable" [file readable $symtcl]

# --- netlist: DC + PULSE(V1 V2 TD TR TF PW PER) -----------------------------
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
check_match "netlist V line DC + PULSE" $nl \
  {(?i)V1 \S+ \S+ 0\.2 PULSE\(0 1\.8 5n 1n 1n 20n 50n ?\)}

# --- setprop round-trip on a couple of fields -------------------------------
xschem setprop instance V1 Vpulse 3.3
xschem setprop instance V1 PER 100n
xschem netlist
set nl2 [read [set fp [open [file join $scratch tb.spice] r]]][close $fp]
check_match "netlist after setprop" $nl2 \
  {(?i)V1 \S+ \S+ 0\.2 PULSE\(0 3\.3 5n 1n 1n 20n 100n ?\)}

# --- static form: seed + apply (GUI-gated) ----------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  global symbol
  set symbol $symsym
  set ::tctx::retval {name=V1 DC=0.2 Vinit=0 Vpulse=1.8 TD=5n TR=1n TF=1n PW=20n PER=50n}
  catch {destroy .dialog}; update
  vpulse::edit_form
  check_true "form dialog opened"     [winfo exists .dialog]
  check "form seeded Vpulse"          $vpulse::val(Vpulse) 1.8
  check "form seeded PW"              $vpulse::val(PW) 20n
  # edit + apply -> instance updated
  set vpulse::val(Vpulse) 5
  set vpulse::val(TD) 10n
  check_true "apply ok"               [vpulse::apply]
  check "applied Vpulse"              [xschem getprop instance V1 Vpulse] 5
  check "applied TD"                  [xschem getprop instance V1 TD] 10n
  catch {destroy .dialog}
  # dispatch (green-but-hollow): core hook lazy-sources + routes
  catch {destroy .dialog}; update
  array unset ::vpulse::val
  catch {rename vpulse::edit_form {}}
  check_true "form proc undefined pre-dispatch" [expr {[info commands vpulse::edit_form] eq {}}]
  set ::tctx::retval {name=V1 DC=0 Vinit=0 Vpulse=2.5 TD=0 TR=1n TF=1n PW=30n PER=60n}
  catch {slickprop::edit_form {}}
  check_true "dispatch opened the cell form"  [winfo exists .dialog]
  check_true "dispatch lazy-sourced the form" [expr {[info commands vpulse::edit_form] ne {}}]
  check "dispatch seeded from retval"         $vpulse::val(Vpulse) 2.5
  catch {destroy .dialog}
} else { puts "form GUI legs skipped (no DISPLAY)" }

file delete -force $scratch
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
