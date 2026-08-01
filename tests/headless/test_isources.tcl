# devices/ipwl + devices/ipulse — PWL / PULSE *current* sources (type=isource,
# name I1). Same generic-form field customization as the v* twins (self-contained
# ipwl/ipulse namespace copies). Covers netlist (I-line + DC + PWL/PULSE) and the
# build_fields integration (ipwl: custom pwl widget; ipulse: friendly labels).
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_isources.tcl
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
set dev     [file join $repo xschem_libs_newsym devices]
set ipwlsym   [file join $dev ipwl symbol ipwl.sym]
set ipulsesym [file join $dev ipulse symbol ipulse.sym]
source [file join $here scratch.tcl]
set scratch [test_scratch isrc]

proc netlist_of {scratch symsym instprops} {
  set sch [file join $scratch tb.sch]
  set f [open $sch w]
  puts $f "v {xschem version=3.4.8RC file_version=1.2}"
  puts $f "G {}"; puts $f "V {}"; puts $f "S {}"; puts $f "E {}"
  puts $f "C \{$symsym\} 100 100 0 0 \{$instprops\}"
  close $f
  set ::netlist_dir $scratch
  catch {xschem set netlist_type spice}
  xschem load $sch
  catch {file delete [file join $scratch tb.spice]}
  xschem netlist
  return [read [set fp [open [file join $scratch tb.spice] r]]][close $fp]
}

# --- ipwl (isource, reuses the PWL custom editor) ---------------------------
catch {xschem load_symbol $ipwlsym}
check "ipwl edit_form ns"     [symattr $ipwlsym edit_form] ipwl
check "ipwl type isource"     [symattr $ipwlsym type] isource
# quoted multi-word default nested in the quoted template: the inner quotes must be
# `\\"` in the K {...} block (the reader unescapes one level) or the template
# truncates to `pwl=0` and a placed ipwl loses its default points. Same defect the
# v* twin carries — see the long note in test_vpwl.tcl.
check "ipwl template keeps the quoted pwl default" \
  [symattr $ipwlsym template] {name=I1 DC=0 pwl="0 0 1n 1m"}
check "ipwl global prop has no junk tokens" \
  [xschem list_tokens [xschem getprop symbol $ipwlsym] 0] {type format template edit_form}
set nl [netlist_of $scratch $ipwlsym {name=I1 DC=1u pwl="0 0 1n 1m 2n 0"}]
check_match "ipwl netlist I-line DC + PWL" $nl {(?i)I1 \S+ \S+ 1u PWL\(0 0 1n 1m 2n 0 ?\)}
xschem clear force
catch {xschem instance $ipwlsym 100 100 0 0}
check "placed ipwl carries the PWL default" [xschem getprop instance I1 pwl] {0 0 1n 1m}

# --- ipulse (isource, friendly-labelled static fields) ----------------------
catch {xschem load_symbol $ipulsesym}
check "ipulse edit_form ns"   [symattr $ipulsesym edit_form] ipulse
check "ipulse type isource"   [symattr $ipulsesym type] isource
set nl2 [netlist_of $scratch $ipulsesym {name=I1 DC=0 Vinit=0 Vpulse=1m TD=5n TR=1n TF=1n PW=20n PER=50n}]
check_match "ipulse netlist I-line DC + PULSE" $nl2 {(?i)I1 \S+ \S+ 0 PULSE\(0 1m 5n 1n 1n 20n 50n ?\)}

# --- generic-form field customization (GUI) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  # ipwl: custom pwl widget in the generic form
  set ::symbol $ipwlsym
  catch {destroy .tf}; frame .tf
  slickprop::build_fields .tf {name=I1 DC=1u pwl="0 0 4n 2m"} {name=I1 DC=0 pwl="0 0 1n 1m"}
  check_true "ipwl: pwl is a custom widget" [expr {[info exists ::slickprop::cur(custom,pwl)] && $::slickprop::cur(custom,pwl)}]
  check_true "ipwl: pwl editor has a spinbox" [expr {[find_cls .tf Spinbox] ne {}}]
  check "ipwl: field_value(pwl) reads editor" [slickprop::field_value pwl] {0 0 4n 2m}
  catch {destroy .tf}
  # ipulse: friendly labels, no custom widget
  set ::symbol $ipulsesym
  catch {destroy .tf}; frame .tf
  slickprop::build_fields .tf {name=I1 DC=0 Vinit=0 Vpulse=1m TD=5n TR=1n TF=1n PW=20n PER=50n} \
                              {name=I1 DC=0 Vinit=0 Vpulse=1 TD=0 TR=1n TF=1n PW=50n PER=100n}
  set gotlabels {}
  foreach w [winfo children .tf] { catch { if {[winfo class $w] eq "Label"} { lappend gotlabels [$w cget -text] } } }
  check_true "ipulse: friendly label 'Period (PER)'" [expr {[lsearch -exact $gotlabels {Period (PER)}] >= 0}]
  check_true "ipulse: no custom widget (no spinbox)"  [expr {[find_cls .tf Spinbox] eq {}}]
  catch {destroy .tf}
} else { puts "build_fields GUI legs skipped (no DISPLAY)" }

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
