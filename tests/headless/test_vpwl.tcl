# devices/vpwl custom cell — pure PWL helpers, netlist format (DC + PWL, spaced
# `pwl` quoting round-trip), and the cell-declared custom-form hook.
#   run:  ./src/xschem --pipe -q --nolog --script tests/headless/test_vpwl.tcl
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

set here   [file normalize [file dirname [info script]]]
set repo   [file normalize [file join $here .. ..]]
set symdir [file join $repo xschem_libs_newsym devices vpwl symbol]
set symsym [file join $symdir vpwl.sym]
set symtcl [file join $symdir vpwl.tcl]
set scratch [file normalize [file join [pwd] _vpwl_[pid]]]
file delete -force $scratch; file mkdir $scratch

# --- pure helpers (source the cell's companion tcl directly) ----------------
source $symtcl
check "split 4 tok -> 2 pairs"        [vpwl::split_pairs {0 0 1n 1}]        {{0 0} {1n 1}}
check "split odd drops trailing tok"  [vpwl::split_pairs {0 0 1n}]          {{0 0}}
check "join full"                     [vpwl::join_pairs {{0 0} {1n 1}}]     {0 0 1n 1}
check "join stops at interior gap"    [vpwl::join_pairs {{0 0} {{} {}} {2n 2}}] {0 0}
check "prefix stops at gap"           [vpwl::prefix_pairs {{0 0} {{} {}} {2n 2}}] {{0 0}}
check "validate ok (>=2)"             [vpwl::validate {{0 0} {1n 1}}]       {}
check_true "validate <2 fails"        [expr {[vpwl::validate {{0 0}}] ne {}}]
check_true "validate leading-gap fails" [expr {[vpwl::validate {{{} {}} {1n 1}}] ne {}}]

# --- symbol declares the custom form + the netlist format -------------------
proc symattr {sym tok} { set r {}; catch {set r [string trim [xschem getprop symbol $sym $tok]]}; return $r }
catch {xschem load_symbol $symsym}
check "symbol edit_form attr"   [symattr $symsym edit_form] vpwl::edit_form
check "symbol netlist format"   [symattr $symsym format]    {@name @pinlist @DC PWL(@pwl )}
check_true "companion tcl readable" [file readable $symtcl]

# --- netlist: DC + PWL, spaced `pwl` value survives save/netlist ------------
set sch [file join $scratch tb.sch]
set f [open $sch w]
puts $f "v {xschem version=3.4.8RC file_version=1.2}"
puts $f "G {}"
puts $f "V {}"
puts $f "S {}"
puts $f "E {}"
puts $f "C \{$symsym\} 100 100 0 0 \{name=V1 DC=0.5 pwl=\"0 0 1n 1 2n 0\"\}"
close $f

set ::netlist_dir $scratch
catch {xschem set netlist_type spice}
xschem load $sch
set out [file join $scratch tb.spice]
catch {file delete $out}
xschem netlist
set nl [read [set fp [open $out r]]][close $fp]
check_match "netlist V line DC + PWL"    $nl {(?i)V1 \S+ \S+ 0\.5 PWL\(0 0 1n 1 2n 0 ?\)}

# --- setprop with a SPACED value quotes correctly (the risky path) ----------
xschem setprop instance V1 pwl {5 5 6n 6}
xschem setprop instance V1 DC 1.2
check "get_tok back the spaced pwl" [xschem getprop instance V1 pwl] {5 5 6n 6}
xschem netlist $out
set nl2 [read [set fp [open $out r]]][close $fp]
check_match "netlist after setprop (quoting ok)" $nl2 {(?i)V1 \S+ \S+ 1\.2 PWL\(5 5 6n 6 ?\)}

# --- custom form: seed / dynamic N / grey-cascade / apply (GUI-gated) -------
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  global symbol
  set symbol $symsym
  set ::tctx::retval {name=V1 DC=0.5 pwl="0 0 1n 1"}
  catch {destroy .dialog}
  vpwl::edit_form
  check_true "form dialog opened"        [winfo exists .dialog]
  check "form seeded N from pwl"         $vpwl::npts 2
  check "row0 time seeded"               $vpwl::tval(0) 0
  check "row1 time seeded"               $vpwl::tval(1) 1n
  # grow to 4 points
  set vpwl::npts 4
  vpwl::on_npts
  check_true "grew to 4 rows"            [winfo exists .dialog.pts.t3]
  # cascade: rows 0,1 complete; 2,3 empty -> row2 editable, row3 greyed
  set vpwl::tval(2) {}; set vpwl::vval(2) {}
  vpwl::refresh_cascade
  check "row2 enabled (row1 complete)"   [.dialog.pts.t2 cget -state] normal
  check "row3 disabled (row2 empty)"     [.dialog.pts.t3 cget -state] disabled
  # fill row2 -> row3 ungreys
  set vpwl::tval(2) 2n; set vpwl::vval(2) 0
  vpwl::refresh_cascade
  check "row3 enabled after row2 filled" [.dialog.pts.t3 cget -state] normal
  # apply -> DC + joined pwl (row3 empty -> dropped by prefix)
  set vpwl::dc 0.9
  check_true "apply ok"                  [vpwl::apply]
  check "applied DC"                     [xschem getprop instance V1 DC] 0.9
  check "applied pwl (prefix; row3 dropped)" [xschem getprop instance V1 pwl] {0 0 1n 1 2n 0}
  catch {destroy .dialog}
} else { puts "form GUI leg skipped (no DISPLAY)" }

# --- the CORE hook: slickprop::edit_form reads the symbol's edit_form attr,
#     lazily sources the companion .tcl, and routes to it (green-but-hollow:
#     delete the form proc first, prove the dispatch re-loads + calls it). ----
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  catch {destroy .dialog}; update
  array unset ::vpwl::tval; array unset ::vpwl::vval
  catch {rename vpwl::edit_form {}}
  check_true "form proc undefined pre-dispatch" [expr {[info commands vpwl::edit_form] eq {}}]
  set symbol $symsym
  set ::tctx::retval {name=V1 DC=0.1 pwl="0 0 3n 3"}
  catch {slickprop::edit_form {}}
  check_true "dispatch opened the cell form"    [winfo exists .dialog]
  check_true "dispatch lazy-sourced the form"   [expr {[info commands vpwl::edit_form] ne {}}]
  check "dispatch seeded from retval"           $vpwl::tval(1) 3n
  catch {destroy .dialog}
} else { puts "dispatch GUI leg skipped (no DISPLAY)" }

file delete -force $scratch
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
